"""Unit tests for the demo handler. No AWS credentials required."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

APP_DIR = Path(__file__).resolve().parents[1] / "app"
sys.path.insert(0, str(APP_DIR))

import handler as handler_module  # noqa: E402


class FakeContext:
    function_version = "7"
    aws_request_id = "test-request-id"


def _write_release(path: Path, label: str, fail_mode: str) -> None:
    path.write_text(json.dumps({"label": label, "fail_mode": fail_mode}), encoding="utf-8")


def test_healthy_release_returns_200_with_version_marker(monkeypatch, tmp_path):
    release = tmp_path / "release.json"
    _write_release(release, "candidate-healthy", "off")
    monkeypatch.setattr(handler_module, "_RELEASE_FILE", release)

    response = handler_module.handler({}, FakeContext())

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["message"] == "ok"
    assert body["version"] == "candidate-healthy"
    assert body["function_version"] == "7"


def test_faulty_release_raises_instead_of_returning_500(monkeypatch, tmp_path):
    release = tmp_path / "release.json"
    _write_release(release, "candidate-faulty", "always")
    monkeypatch.setattr(handler_module, "_RELEASE_FILE", release)

    # Raising increments Lambda Errors; returning statusCode=500 would not.
    with pytest.raises(RuntimeError, match="candidate-faulty"):
        handler_module.handler({}, FakeContext())


def test_environment_fallback_when_release_file_is_absent(monkeypatch, tmp_path):
    monkeypatch.setattr(handler_module, "_RELEASE_FILE", tmp_path / "missing.json")
    monkeypatch.setenv("RELEASE_LABEL", "local-baseline")
    monkeypatch.setenv("FAIL_MODE", "off")

    body = json.loads(handler_module.handler({}, FakeContext())["body"])

    assert body["version"] == "local-baseline"


def test_release_metadata_rejects_unknown_fail_mode_by_ignoring_it(monkeypatch, tmp_path):
    release = tmp_path / "release.json"
    _write_release(release, "candidate", "sometimes")
    monkeypatch.setattr(handler_module, "_RELEASE_FILE", release)

    # Only the explicit "always" sentinel fails; everything else stays healthy.
    response = handler_module.handler({}, FakeContext())

    assert response["statusCode"] == 200
