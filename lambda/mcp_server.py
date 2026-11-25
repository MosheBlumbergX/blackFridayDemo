"""Minimal MCP server (streamable HTTP, JSON responses) for the deal hunter.

Tools:
  search_prices(query)            SerpAPI Google Shopping (UK), with the price
                                  statistics computed here so the LLM judges
                                  numbers instead of calculating them.
  send_email(to, subject, body)   Amazon SES.

Secrets come from environment variables set by Terraform:
  MCP_TOKEN, PRICE_API_KEY, SES_SENDER, ALLOWED_RECIPIENT
"""
import json
import logging
import os
import re
import statistics
import urllib.parse
import urllib.request


log = logging.getLogger()
log.setLevel(logging.INFO)

PROTOCOL_VERSION = "2025-03-26"
SERVER_INFO = {"name": "deal-hunter-mcp", "version": "1.0.0"}

TOOLS = [
    {
        "name": "search_prices",
        "description": (
            "Search UK online shops (marketplaces and resale excluded) for a product and return the cheapest listings "
            "plus statistics: cheapest price, median price, how far the cheapest is "
            "below the median, and any claimed discount (old price) per listing."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"query": {"type": "string", "description": "Product to search for"}},
            "required": ["query"],
        },
    },
    {
        "name": "send_email",
        "description": "Send a plain text email with the deal verdict.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Ignored. Mail always goes to the configured recipient."},
                "subject": {"type": "string"},
                "body": {"type": "string"},
            },
            "required": ["subject", "body"],
        },
    },
]

# Marketplaces, resale shops and importers are not Black Friday shops. Third-party
# sellers on a marketplace appear as "Shop - Seller" and are ignored too.
BLOCKED_SHOPS = (
    "ebay", "cex", "cash converters", "cashconverters", "back market", "musicmagpie", "gumtree",
    "vinted", "depop", "facebook", "preloved", "u-buy", "onbuy", "wish", "temu", "aliexpress",
    "alibaba", "shein", "etsy", "notonthehighstreet",
)


def _trusted(source: str) -> bool:
    source = (source or "").lower().strip()
    return bool(source) and " - " not in source and not any(b in source for b in BLOCKED_SHOPS)


MIN_LISTINGS = 4  # below this there is nothing sensible to compare against


def _normalise(text: str) -> str:
    text = (text or "").lower().replace("playstation 5", "ps5").replace("playstation5", "ps5")
    return re.sub(r"[^a-z0-9 ]+", " ", text)


def summarise(data: dict, query: str) -> dict:
    """Turn a SerpAPI Google Shopping response into verdict-ready statistics."""
    wanted = _normalise(query).split()
    listings, excluded = [], 0
    for item in data.get("shopping_results", []):
        price = item.get("extracted_price")
        title_words = set(_normalise(item.get("title")).split())
        if (
            price is None
            or item.get("second_hand_condition")
            or not _trusted(item.get("source"))
            or not all(w in title_words for w in wanted)
        ):
            excluded += 1
            continue
        old = item.get("extracted_old_price")
        listings.append(
            {
                "shop": item.get("source"),
                "title": (item.get("title") or "")[:90],
                "price_gbp": price,
                "claimed_old_price_gbp": old,
                "claimed_saving_pct": round(100 * (old - price) / old, 1) if old else None,
            }
        )
    # Prices far below the rest are usually accessories, parts or mislabelled items.
    if len(listings) >= 3:
        median = statistics.median(x["price_gbp"] for x in listings)
        kept = [x for x in listings if x["price_gbp"] >= 0.5 * median]
        excluded += len(listings) - len(kept)
        listings = kept
    if len(listings) < MIN_LISTINGS:
        return {
            "query": query,
            "found": False,
            "reason": f"fewer than {MIN_LISTINGS} comparable listings from UK shops",
            "excluded_listings": excluded,
        }

    listings.sort(key=lambda x: x["price_gbp"])
    median = statistics.median(x["price_gbp"] for x in listings)
    cheapest = listings[0]
    return {
        "query": query,
        "found": True,
        "listing_count": len(listings),
        "excluded_listings": excluded,
        "cheapest": cheapest,
        "median_price_gbp": median,
        "cheapest_below_median_pct": round(100 * (median - cheapest["price_gbp"]) / median, 1),
        "top_listings": listings[:6],
    }


def search_prices(query: str) -> dict:
    params = urllib.parse.urlencode(
        {
            "engine": "google_shopping",
            "q": query,
            "gl": "uk",
            "hl": "en",
            "google_domain": "google.co.uk",
            "api_key": os.environ["PRICE_API_KEY"],
        }
    )
    with urllib.request.urlopen(f"https://serpapi.com/search.json?{params}", timeout=25) as r:
        return summarise(json.load(r), query)


def send_email(subject: str, body: str, to: str = "") -> dict:
    """Send to the one configured recipient. The model-supplied `to` is ignored, so a
    public endpoint can never be used to email anyone else (and the SES sandbox
    only delivers to verified addresses anyway)."""
    import boto3  # in the Lambda runtime; loaded only when an email is sent

    recipient = os.environ["ALLOWED_RECIPIENT"]
    boto3.client("ses").send_email(
        Source=os.environ["SES_SENDER"],
        Destination={"ToAddresses": [recipient]},
        Message={"Subject": {"Data": subject[:200]}, "Body": {"Text": {"Data": body[:5000]}}},
    )
    log.info("email_sent subject=%s", subject[:120])
    return {"sent": True}


def _tool_result(payload, is_error=False):
    return {"content": [{"type": "text", "text": json.dumps(payload)}], "isError": is_error}


def _handle(msg: dict):
    method, mid = msg.get("method"), msg.get("id")
    if mid is None:  # notification, no response
        return None
    if method == "initialize":
        result = {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": SERVER_INFO,
        }
    elif method == "ping":
        result = {}
    elif method == "tools/list":
        result = {"tools": TOOLS}
    elif method == "tools/call":
        params = msg.get("params", {})
        name, args = params.get("name"), params.get("arguments", {}) or {}
        # Log what the agent asked for (never the token or the API key).
        log.info("tool_call name=%s query=%s subject=%s", name, args.get("query"), args.get("subject"))
        try:
            if name == "search_prices":
                result = _tool_result(search_prices(str(args["query"])))
            elif name == "send_email":
                result = _tool_result(send_email(str(args["subject"]), str(args["body"]), str(args.get("to", ""))))
            else:
                return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32602, "message": f"unknown tool {name}"}}
        except Exception as exc:  # report tool failures to the model, not as HTTP errors
            log.error("tool_error name=%s error=%s", name, str(exc)[:200])
            result = _tool_result({"error": str(exc)[:300]}, is_error=True)
    else:
        return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": "method not found"}}
    return {"jsonrpc": "2.0", "id": mid, "result": result}


def _response(status, payload=None):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload) if payload is not None else "",
    }


def handler(event, _context):
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    if headers.get("authorization") != f"Bearer {os.environ['MCP_TOKEN']}":
        return _response(401, {"error": "unauthorised"})
    method = event.get("requestContext", {}).get("http", {}).get("method", "POST")
    if method != "POST":
        return _response(405, {"error": "use POST"})
    try:
        msg = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "bad json"})

    if isinstance(msg, list):  # batch
        out = [r for r in (_handle(m) for m in msg) if r is not None]
        return _response(200, out) if out else _response(202)
    out = _handle(msg)
    return _response(200, out) if out is not None else _response(202)
