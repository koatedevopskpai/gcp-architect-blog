"""Minimal Cloud Run canary demo.

- /healthz always returns 200 (startup probe).
- /version returns the revision name.
- FAIL_MODE=1 returns HTTP 500 for application paths, which is the fault the
  release ladder must stop.

Standard library only, so the image stays small and the failure is the app,
not a missing dependency.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REVISION = os.environ.get("K_REVISION", "local")
FAIL_MODE = os.environ.get("FAIL_MODE", "0") == "1"


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - stdlib API
        if self.path.split("?")[0] == "/healthz":
            self._send(200, {"status": "ok", "revision": REVISION})
            return

        if FAIL_MODE:
            self._send(500, {"error": "injected failure", "revision": REVISION})
            return

        if self.path.split("?")[0] == "/version":
            self._send(200, {"revision": REVISION})
            return

        self._send(200, {"ok": True, "revision": REVISION})

    def log_message(self, fmt: str, *args) -> None:
        # Keep the demo output quiet; Cloud Run request logs are the evidence.
        return


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
