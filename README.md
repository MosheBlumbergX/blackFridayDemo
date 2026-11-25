# Black Friday Deal Hunter

You see "50% off" on a pair of headphones, and you wonder whether it is a real deal or a price that was inflated last week. You would have to open ten shop tabs to check.

This demo does that check in a stream. A Flink agent in Confluent Cloud takes each product on your Christmas list, searches real UK shop prices through a tool, compares them, and emails you only when it finds a best deal or a fake discount. Think of a friend who hates being ripped off and checks every shop for you, then texts you only when something is worth it.

## Overview

- **Input:** a shopping list of five gift ideas on a Kafka topic (`wanted_products`).
- **Agent:** `CREATE AGENT` in Flink SQL, running with `AI_RUN_AGENT` as a continuous job.
- **Tools:** an MCP server on AWS Lambda with two tools. `search_prices` queries real UK shop prices (SerpAPI Google Shopping) and computes the median and the gap. `send_email` sends the alert through Amazon SES.
- **Output:** a verdict per product on the `deal_verdicts` topic: `BEST_DEAL`, `FAKE_DISCOUNT`, `OK_PRICE` or `NO_DATA`.

The agent's idea comes from Confluent's price-matching [Lab 1](https://github.com/confluentinc/quickstart-streaming-agents/blob/master/LAB1-Walkthrough.md). Here the agent compares many shops instead of one, and the MCP server is our own, built with Terraform, so anyone can run the demo.

## Architecture

```
 wanted_products ──> Flink job ──> AI_RUN_AGENT(deal_hunter) ──> MCP (AWS Lambda)
 (Python producer)   (Confluent)         |                          ├─ search_prices ──> SerpAPI (UK shops)
                                         |                          └─ send_email ─────> Amazon SES
                                         v
                                  deal_verdicts topic
```

Everything runs in AWS `eu-west-2` (London). Verdict rules live in the agent prompt in `terraform/flink.tf`. The price maths lives in `lambda/mcp_server.py`.

## Quick start

You need Terraform, Python 3, the AWS CLI, `jq`, `zip`, a Confluent Cloud account, a free [SerpAPI](https://serpapi.com) key and AWS credentials.

```bash
cp .env.example .env     # fill it in, see the comments inside
make check               # tools, .env variables, AWS login
make plan                # nothing is created yet
make up                  # creates everything
```

After `make up`, SES emails a verification link to `NOTIFY_EMAIL`. Click it, or no alert emails arrive. Alerts are sent from that same address with no DKIM, so check your **Spam** folder for "Black Friday deal alert" (that is where mine landed).

```bash
make demo                # the scripted run, safe to screen-record
```

## What you will see

`make demo` publishes the five products and prints one line per verdict as they arrive:

```
PRODUCT                  VERDICT         CHEAPEST   MEDIAN  SHOP
Apple AirPods Pro        BEST_DEAL         154.80   183.99  SilentSale
Nintendo Switch 2        OK_PRICE          399.99   440.99  Smyths Toys
LEGO City advent calendar BEST_DEAL          18.39    26.13  Roys Wroxham
Dyson Airwrap            BEST_DEAL         299.99   355.36  Dyson UK
Ninja air fryer          NO_DATA        Not found Not found  Not found
```

One alert email per best deal arrives (check Spam).

## Results

On the first real run (25 November 2026): 3 of 5 products had a best deal, 1 was an ordinary price, 1 had too little data, and no fake discounts were found. Details, and what surprised me, are in [docs/findings.md](docs/findings.md). Prices are a snapshot and will have changed.

Two honest caveats: raw shopping results contain used items and resale shops, so the Lambda filters them, and small shops can make a thin median. Treat a verdict as a lead to check.

## Teardown

The Confluent Standard cluster and the Flink job are billed hourly. Destroy everything when you are done:

```bash
make down
```

All AWS resources carry the mandatory tags, including `cflt_keep_until`. Set `KEEP_UNTIL` in `.env`.

## Further reading

- [docs/concepts.md](docs/concepts.md): how streaming agents and MCP tools work
- [docs/troubleshooting.md](docs/troubleshooting.md): real errors hit during the build
- [Streaming Agents in Confluent Cloud](https://docs.confluent.io/cloud/current/ai/streaming-agents/overview.html)
- [CREATE AGENT](https://docs.confluent.io/cloud/current/flink/reference/statements/create-agent.html)
