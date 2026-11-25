"""Publish the shopping list to the wanted_products topic, one run at a time.

Each product is a search query for a popular UK Christmas gift. The Flink agent
picks each one up, searches real shop prices and emails a verdict.
"""
import argparse
import time
from datetime import datetime, timezone
from pathlib import Path

from confluent_kafka import SerializingProducer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.json_schema import JSONSerializer
from confluent_kafka.serialization import StringSerializer

from common import kafka_conf, load_client_env, sr_conf

TOPIC = "wanted_products"

# Seasonal gift ideas for the run up to Christmas.
PRODUCTS = [
    ("switch2", "Nintendo Switch 2"),
    ("airpods", "Apple AirPods Pro"),
    ("lego-advent", "LEGO City advent calendar"),
    ("air-fryer", "Ninja air fryer"),
    ("airwrap", "Dyson Airwrap"),
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=1, help="how many times to publish the list")
    parser.add_argument("--interval", type=int, default=3600, help="seconds between runs")
    args = parser.parse_args()

    cfg = load_client_env()
    sr = SchemaRegistryClient(sr_conf(cfg))
    # The Flink table owns the schema: use the latest version, never register one here.
    schema_str = sr.get_latest_version(f"{TOPIC}-value").schema.schema_str
    serializer = JSONSerializer(
        schema_str,
        sr,
        conf={"auto.register.schemas": False, "use.latest.version": True},
    )
    producer = SerializingProducer(
        {**kafka_conf(cfg), "key.serializer": StringSerializer("utf_8"), "value.serializer": serializer}
    )

    for n in range(args.runs):
        run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        print(f"Run {n + 1}/{args.runs}: publishing {len(PRODUCTS)} wanted products (run_id={run_id})")
        for product_id, query in PRODUCTS:
            producer.produce(
                TOPIC,
                key=f"{run_id}-{product_id}",
                value={"run_id": run_id, "product_id": product_id, "product_query": query},
            )
            print(f"  wanted: {query}")
        producer.flush()
        # Lets show_verdicts.py show only this run.
        (Path(__file__).resolve().parents[2] / ".generated" / "last_run_id").write_text(run_id)
        if n + 1 < args.runs:
            time.sleep(args.interval)


if __name__ == "__main__":
    main()
