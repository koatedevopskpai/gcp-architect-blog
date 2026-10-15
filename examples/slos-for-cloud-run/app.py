"""Fault-injecting demo service for the SLO post (Blog 4).

Two knobs, both driven per-request so we can induce a *real* burn without
redeploying:

  GET /                                  -> 200 fast (baseline traffic)
  GET /health                            -> 200 "ok" (uptime checks)
  GET /work?fail=1                       -> 500 (availability burn)
  GET /work?latency_ms=2000              -> 200, after sleeping 2s (latency burn)

A baseline random failure rate is also available via the FAIL_RATE env var, so
the service keeps burning slowly even under a plain load generator.
"""

import os
import random
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

PORT = int(os.environ.get("PORT", "8080"))
FAIL_RATE = float(os.environ.get("FAIL_RATE", "0"))  # baseline random 500s


class Handler(BaseHTTPRequestHandler):
    def _respond(self, code: int, body: str) -> None:
        payload = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path == "/health":
            return self._respond(200, "ok")

        if parsed.path == "/work":
            # Induced latency.
            latency_ms = int(qs.get("latency_ms", ["0"])[0])
            if latency_ms > 0:
                time.sleep(latency_ms / 1000.0)

            # Induced failure (explicit flag wins; else the baseline FAIL_RATE).
            fail = qs.get("fail", ["0"])[0] == "1"
            if not fail and FAIL_RATE > 0:
                fail = random.random() < FAIL_RATE
            if fail:
                return self._respond(500, "induced failure")

            return self._respond(200, "ok")

        return self._respond(200, "hello from the SLO demo\n")

    def log_message(self, fmt, *args):
        print(fmt % args)


if __name__ == "__main__":
    # Threaded so concurrent requests (e.g. the load generator's slow calls)
    # don't queue behind each other — Cloud Run sends concurrent requests.
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
