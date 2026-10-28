#!/usr/bin/env python3
"""Bounded load generator for the safe-releases demo.

Sends a fixed request rate for a fixed duration, then writes a JSON summary
with status codes and observed release labels. It is a smoke load, not a
benchmark: the goal is a measurable canary sample, not throughput testing.

Usage:
    python scripts/load.py --url https://... --seconds 360 --rate 10 \
        --output evidence/raw/<run-id>/load.json
"""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--seconds", type=int, default=360)
    parser.add_argument("--rate", type=float, default=10.0, help="requests per second")
    parser.add_argument("--max-requests", type=int, default=5000)
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    if args.rate <= 0:
        raise SystemExit("--rate must be positive")

    status_counts: Counter[int] = Counter()
    version_counts: Counter[str] = Counter()
    started = time.monotonic()
    deadline = started + args.seconds
    next_send = started
    sent = 0

    while time.monotonic() < deadline and sent < args.max_requests:
        now = time.monotonic()
        if now < next_send:
            time.sleep(next_send - now)
        next_send += 1.0 / args.rate

        status = 0
        body = ""
        try:
            with urllib.request.urlopen(args.url, timeout=args.timeout) as response:
                status = response.status
                body = response.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            status = exc.code
            body = exc.read().decode("utf-8", errors="replace")
        except Exception as exc:  # noqa: BLE001 - recorded as status 0
            body = str(exc)

        sent += 1
        status_counts[status] += 1
        try:
            version_counts[json.loads(body).get("version", "unknown")] += 1
        except (json.JSONDecodeError, AttributeError):
            version_counts["unparsed"] += 1

    elapsed = time.monotonic() - started
    summary = {
        "url": args.url,
        "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(started and time.time() - elapsed)),
        "elapsed_seconds": round(elapsed, 3),
        "configured_rate_per_second": args.rate,
        "requests_sent": sent,
        "status_counts": {str(k): v for k, v in sorted(status_counts.items())},
        "version_counts": dict(sorted(version_counts.items())),
        "errors": sum(v for k, v in status_counts.items() if k == 0 or k >= 500),
    }

    print(json.dumps(summary, indent=2))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
