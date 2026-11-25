"""Read deal_verdicts and print one line per product, with a tally at the end."""
import argparse
import collections
import json
import time
import uuid
from pathlib import Path

from confluent_kafka import Consumer

from common import kafka_conf, load_client_env

TOPIC = "deal_verdicts"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expect", type=int, default=5, help="stop after this many verdicts")
    parser.add_argument("--timeout", type=int, default=300, help="give up after this many seconds")
    parser.add_argument("--run-id", default="", help="only show this run (default: the last run published)")
    args = parser.parse_args()
    run_id = args.run_id
    last = Path(__file__).resolve().parents[2] / ".generated" / "last_run_id"
    if not run_id and last.exists():
        run_id = last.read_text().strip()

    consumer = Consumer(
        {
            **kafka_conf(load_client_env()),
            "group.id": f"verdict-viewer-{uuid.uuid4().hex[:8]}",
            "auto.offset.reset": "earliest",
        }
    )
    consumer.subscribe([TOPIC])

    tally = collections.Counter()
    seen = 0
    deadline = time.time() + args.timeout
    print(f"{'PRODUCT':<24} {'VERDICT':<14} {'CHEAPEST':>9} {'MEDIAN':>8}  SHOP")
    while seen < args.expect and time.time() < deadline:
        msg = consumer.poll(2.0)
        if msg is None or msg.error():
            continue
        # json-registry framing: 1 magic byte + 4 byte schema id, then JSON.
        row = json.loads(msg.value()[5:])
        if run_id and row.get("run_id") != run_id:
            continue
        verdict = row.get("verdict") or "UNPARSED"
        tally[verdict] += 1
        seen += 1
        print(
            f"{row.get('product_query', ''):<24} {verdict:<14} "
            f"{row.get('cheapest_price') or '-':>9} {row.get('median_price') or '-':>8}  "
            f"{row.get('cheapest_shop') or '-'}"
        )
    consumer.close()

    print("\nTally:", ", ".join(f"{k}={v}" for k, v in sorted(tally.items())) or "no verdicts received")
    if seen < args.expect:
        raise SystemExit(f"Only {seen}/{args.expect} verdicts arrived within {args.timeout}s.")


if __name__ == "__main__":
    main()
