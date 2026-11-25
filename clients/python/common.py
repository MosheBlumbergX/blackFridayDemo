"""Shared config loading for the demo clients. Reads .generated/client.env."""
import os
from pathlib import Path


def load_client_env() -> dict:
    path = Path(__file__).resolve().parents[2] / ".generated" / "client.env"
    if not path.exists():
        raise SystemExit("Missing .generated/client.env. Run 'make up' first.")
    cfg = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            cfg[key.strip()] = value.strip()
    return cfg


def kafka_conf(cfg: dict) -> dict:
    return {
        "bootstrap.servers": cfg["BOOTSTRAP_SERVERS"],
        "security.protocol": "SASL_SSL",
        "sasl.mechanisms": "PLAIN",
        "sasl.username": cfg["KAFKA_API_KEY"],
        "sasl.password": cfg["KAFKA_API_SECRET"],
    }


def sr_conf(cfg: dict) -> dict:
    return {
        "url": cfg["SCHEMA_REGISTRY_URL"],
        "basic.auth.user.info": f'{cfg["SCHEMA_REGISTRY_API_KEY"]}:{cfg["SCHEMA_REGISTRY_API_SECRET"]}',
    }


def env_or(name: str, default: str) -> str:
    return os.environ.get(name, default)
