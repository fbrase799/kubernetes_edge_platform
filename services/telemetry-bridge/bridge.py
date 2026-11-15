#!/usr/bin/env python3
"""Poll Open Gateway current telemetry and write numeric readings to InfluxDB."""

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

GATEWAY_URL = os.environ["GATEWAY_URL"].rstrip("/")
INFLUX_URL = os.environ["INFLUX_URL"].rstrip("/")
INFLUX_ORG = os.environ["INFLUX_ORG"]
INFLUX_BUCKET = os.environ["INFLUX_BUCKET"]
INFLUX_TOKEN = os.environ["INFLUX_TOKEN"]
INTERVAL = float(os.environ.get("POLL_INTERVAL_SECONDS", "5"))


def log(message: str) -> None:
    stamp = datetime.now(timezone.utc).isoformat()
    print(f"{stamp} {message}", flush=True)


def parse_time_ns(text: str | None) -> int | None:
    if not text:
        return None
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    return int(parsed.timestamp() * 1_000_000_000)


def escape_tag(value: str) -> str:
    return value.replace("\\", "\\\\").replace(" ", "\\ ").replace(",", "\\,").replace("=", "\\=")


def line_for(reading: dict) -> str | None:
    value = reading.get("value")
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    device = escape_tag(str(reading.get("deviceId") or "unknown"))
    capability = escape_tag(str(reading.get("capabilityId") or "unknown"))
    line = f"sensor,device_id={device},capability_id={capability} value={float(value)}"
    timestamp = parse_time_ns(reading.get("sourceTimestamp"))
    if timestamp is not None:
        line += f" {timestamp}"
    return line


def poll() -> None:
    request = urllib.request.Request(f"{GATEWAY_URL}/api/v1/telemetry/current")
    with urllib.request.urlopen(request, timeout=5) as response:
        document = json.load(response)
    lines = []
    for reading in document.get("readings", []):
        line = line_for(reading)
        if line is not None:
            lines.append(line)
    if not lines:
        log("no numeric readings")
        return
    payload = "\n".join(lines).encode()
    query = urllib.parse.urlencode(
        {"org": INFLUX_ORG, "bucket": INFLUX_BUCKET, "precision": "ns"}
    )
    write = urllib.request.Request(
        f"{INFLUX_URL}/api/v2/write?{query}",
        data=payload,
        method="POST",
    )
    write.add_header("Authorization", f"Token {INFLUX_TOKEN}")
    write.add_header("Content-Type", "text/plain; charset=utf-8")
    with urllib.request.urlopen(write, timeout=5) as response:
        log(f"wrote {len(lines)} points status={response.status}")


def main() -> None:
    log("telemetry bridge started")
    while True:
        try:
            poll()
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            log(f"poll failed: {exc}")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
