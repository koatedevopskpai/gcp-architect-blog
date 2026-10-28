"""Minimal demo handler for the Lambda safe-releases example.

The release label and fault mode are baked into the deployment artifact as
``release.json`` so that a published Lambda version is self-describing.
Environment variables are used only as a fallback for local runs.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

_RELEASE_FILE = Path(__file__).with_name("release.json")


def release_metadata() -> dict[str, str]:
    """Return the release metadata packaged with this version."""
    if _RELEASE_FILE.exists():
        return json.loads(_RELEASE_FILE.read_text(encoding="utf-8"))
    return {
        "label": os.environ.get("RELEASE_LABEL", "unknown"),
        "fail_mode": os.environ.get("FAIL_MODE", "off"),
    }


def handler(event, context):
    """Return a version-stamped 200, or raise to simulate a bad release.

    The fault deliberately raises instead of returning ``statusCode=500``.
    A returned 500 is a successful invocation and does not increment the
    Lambda ``Errors`` metric that drives CodeDeploy automatic rollback.
    """
    meta = release_metadata()
    label = meta.get("label", "unknown")

    if meta.get("fail_mode") == "always":
        raise RuntimeError(f"injected failure from release {label}")

    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(
            {
                "message": "ok",
                "version": label,
                "function_version": getattr(context, "function_version", "local"),
                "request_id": getattr(context, "aws_request_id", "local"),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        ),
    }
