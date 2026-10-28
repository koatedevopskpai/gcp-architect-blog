#!/usr/bin/env python3
"""Phase 2 rehearsal: prove the artifacts and load generator behave as claimed.

No AWS credentials or spend. Run from the example root:

    python scripts/rehearse.py

Checks:
  1. Each built artifact carries the expected release.json and AppSpec versions.
  2. The baseline and healthy handlers return 200 with the right version marker.
  3. The faulty handler raises (so Lambda Errors increments) instead of returning 500.
  4. The bounded load generator produces a correct summary against a local server.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import threading
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"

EXPECTED = {
    "baseline": ("baseline", "off", "ok"),
    "healthy": ("candidate-healthy", "off", "ok"),
    "faulty": ("candidate-faulty", "always", "raised"),
}

failures: list[str] = []


def check(condition: bool, message: str) -> None:
    if condition:
        print(f"  PASS  {message}")
    else:
        print(f"  FAIL  {message}")
        failures.append(message)


def build_all() -> None:
    for release in EXPECTED:
        subprocess.run(
            [sys.executable, str(SCRIPTS / "build.py"), release],
            check=True,
            capture_output=True,
            text=True,
        )
    print("Built baseline, healthy and faulty artifacts")


def invoke(zip_path: Path, release: str):
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(zip_path) as archive:
            archive.extractall(tmp)
        spec = importlib.util.spec_from_file_location(
            f"handler_{release}", Path(tmp) / "handler.py"
        )
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)

        context = type(
            "Context",
            (),
            {"function_version": "99", "aws_request_id": "rehearsal"},
        )()
        try:
            response = module.handler({}, context)
            return "ok", json.loads(response["body"])["version"]
        except RuntimeError as exc:
            return "raised", str(exc)


def check_artifacts() -> None:
    print("\nArtifacts")
    for release, (label, fail_mode, behaviour) in EXPECTED.items():
        zip_path = ROOT / "build" / f"{release}.zip"
        with zipfile.ZipFile(zip_path) as archive:
            names = set(archive.namelist())
            meta = json.loads(archive.read("release.json"))

        check(names == {"handler.py", "release.json"}, f"{release}: expected files")
        check(meta["label"] == label, f"{release}: label is {label}")
        check(meta["fail_mode"] == fail_mode, f"{release}: fail_mode is {fail_mode}")

        outcome, detail = invoke(zip_path, release)
        if behaviour == "ok":
            check(outcome == "ok" and detail == label, f"{release}: returns 200 as {label}")
        else:
            check(outcome == "raised" and label in detail, f"{release}: raises with {label}")


class VersionHandler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802 - stdlib API
        body = json.dumps({"version": "rehearsal-v1"}).encode()
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):  # silence test output
        pass


def check_load() -> None:
    print("\nLoad generator")
    server = ThreadingHTTPServer(("127.0.0.1", 0), VersionHandler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "load.json"
            subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "load.py"),
                    "--url",
                    f"http://127.0.0.1:{port}/",
                    "--seconds",
                    "2",
                    "--rate",
                    "5",
                    "--output",
                    str(output),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            summary = json.loads(output.read_text())
    finally:
        server.shutdown()
        server.server_close()

    check(summary["requests_sent"] >= 5, "sent at least 5 requests")
    check(summary["status_counts"].get("200", 0) >= 5, "counted 200 responses")
    check(summary["version_counts"].get("rehearsal-v1", 0) >= 5, "counted the version marker")
    check(summary["errors"] == 0, "reported no errors")


def main() -> int:
    build_all()
    check_artifacts()
    check_load()

    print()
    if failures:
        print(f"REHEARSAL FAILED ({len(failures)} check(s))")
        return 1
    print("REHEARSAL PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
