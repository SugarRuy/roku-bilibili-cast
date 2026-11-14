"""Find the Roku IP for LAN tests without reading developer credentials."""
import ipaddress
import os
from pathlib import Path


def roku_ip():
    value = os.environ.get("ROKU_IP")
    if not value:
        config = Path(__file__).resolve().parents[2] / ".env.local"
        if config.exists():
            for line in config.read_text(encoding="utf-8-sig").splitlines():
                if line.startswith("ROKU_IP="):
                    value = line.partition("=")[2].strip()
                    break
    if not value:
        raise SystemExit("Set ROKU_IP or add it to .env.local (see .env.example)")
    return str(ipaddress.IPv4Address(value))
