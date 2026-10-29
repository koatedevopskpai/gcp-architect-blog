#!/usr/bin/env python3
"""Evidence toolkit for gcp-architect-blog.

Generic replacement for the one-off prepare_post.py / finalize_evidence.py
scripts. Every post keeps its public evidence under
`public/evidence/<slug>/` and its run metadata in
`content-ops/evidence/<slug>.json`.

Commands
--------
bundle      Build a verified source ZIP and copy code excerpts into the evidence
            directory. Uses the source's MANIFEST.sha256 when present.
transcript  Normalise a pytest transcript and (optionally) summarise a JUnit XML.
manifest    Hash every file in the evidence directory and write manifest.json.
finalize    transcript + manifest + verify, in one pass.
verify      Check a manifest against the files on disk and the claim tests.

Examples
--------
python scripts/evidence.py bundle \
  --slug my-post --source ../my-lab \
  --notes docs/my-post/PUBLICATION-NOTES.md \
  --excerpts src/app.py,tests/test_app.py

python scripts/evidence.py finalize \
  --slug my-post \
  --config content-ops/evidence/my-post.json \
  --junit work/publication-tests.xml \
  --raw work/test-results.txt \
  --command "python -m pytest -v --junitxml=publication-tests.xml"

python scripts/evidence.py verify --slug my-post

The scripts use only the Python standard library. Python 3.9+ is enough for the
tooling itself; a lab may require a newer runtime (the Azure AI Ops lab tests
require Python 3.14).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import zipfile
from datetime import date, datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path.cwd()
EVIDENCE_ROOT = ROOT / "public" / "evidence"
CONFIG_ROOT = ROOT / "content-ops" / "evidence"
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
JUNK_DIRS = {"__pycache__", ".pytest_cache", ".git", ".venv", "venv", "node_modules", ".mypy_cache", ".ruff_cache"}
JUNK_FILES = {".DS_Store", "Thumbs.db"}


def fail(message: str) -> None:
    print(f"ERROR {message}", file=sys.stderr)
    raise SystemExit(1)


def check_slug(slug: str) -> None:
    if not SLUG_RE.fullmatch(slug):
        fail(f"invalid slug '{slug}'. Use lowercase letters, digits and single hyphens.")


def evidence_dir(slug: str, override: str | None = None) -> Path:
    if override:
        return Path(override).resolve()
    return EVIDENCE_ROOT / slug


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_junk(path: Path) -> bool:
    return any(part in JUNK_DIRS for part in path.parts) or path.name in JUNK_FILES


def walk_files(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file() and not is_junk(path.relative_to(root))
    )


def parse_checksum_manifest(path: Path) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.match(r"^([0-9a-fA-F]{64})\s{2}(.+)$", line)
        if not match:
            fail(f"cannot parse checksum line in {path}: {line}")
        entries.append((match.group(1).lower(), match.group(2).strip()))
    return entries


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def read_config(path: str | None) -> dict:
    if not path:
        return {}
    config_path = Path(path)
    if not config_path.is_absolute():
        config_path = ROOT / config_path
    if not config_path.exists():
        fail(f"config not found: {config_path}")
    return json.loads(config_path.read_text(encoding="utf-8-sig"))


def junit_counts(path: str | None) -> dict | None:
    if not path:
        return None
    junit_path = Path(path)
    if not junit_path.is_absolute():
        junit_path = ROOT / junit_path
    if not junit_path.exists():
        fail(f"JUnit XML not found: {junit_path}")
    root = ET.parse(junit_path).getroot()
    counts = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
    if not suites:
        fail(f"no <testsuite> element in {junit_path}")
    for suite in suites:
        for key in counts:
            counts[key] += int(suite.attrib.get(key, 0))
    counts["passed"] = counts["tests"] - counts["failures"] - counts["errors"] - counts["skipped"]
    return counts


def cmd_bundle(args: argparse.Namespace) -> None:
    check_slug(args.slug)
    source = Path(args.source).resolve()
    if not source.is_dir():
        fail(f"source directory not found: {source}")

    out = evidence_dir(args.slug, args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    zip_name = args.zip_name or f"{source.name}-source.zip"
    zip_path = out / zip_name
    if zip_path.exists() and not args.force:
        fail(f"{zip_path} exists; pass --force to replace it")

    manifest_path = source / args.manifest_name
    if manifest_path.exists():
        entries = parse_checksum_manifest(manifest_path)
        for digest, rel in entries:
            file = source / rel
            if not file.is_file():
                fail(f"manifest lists a missing file: {rel}")
            if sha256(file) != digest:
                fail(f"source hash mismatch: {rel}")
        manifest_text = manifest_path.read_text(encoding="utf-8")
        print(f"verified {len(entries)} file(s) against {args.manifest_name}")
    else:
        entries = [(sha256(file), file.relative_to(source).as_posix()) for file in walk_files(source)]
        manifest_text = "\n".join(f"{digest}  {rel}" for digest, rel in entries) + "\n"
        print(f"generated {args.manifest_name} for {len(entries)} file(s)")

    notes_text = None
    if args.notes:
        notes_path = Path(args.notes)
        if not notes_path.is_absolute():
            notes_path = ROOT / notes_path
        if not notes_path.exists():
            fail(f"notes file not found: {notes_path}")
        notes_text = notes_path.read_text(encoding="utf-8")

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for digest, rel in entries:
            archive.write(source / rel, f"{source.name}/{rel}")
        archive.writestr(f"{source.name}/{args.manifest_name}", manifest_text)
        if notes_text is not None:
            archive.writestr(f"{source.name}/PUBLICATION-NOTES.md", notes_text)

    copied = []
    for rel in [item.strip() for item in (args.excerpts or "").split(",") if item.strip()]:
        source_file = source / rel
        if not source_file.is_file():
            fail(f"excerpt not found in source: {rel}")
        target = out / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_file, target)
        copied.append(rel)

    print(f"wrote {display_path(zip_path)} ({zip_path.stat().st_size:,} bytes)")
    print(f"sha256 {sha256(zip_path)}")
    if copied:
        print("copied excerpts: " + ", ".join(copied))


def cmd_transcript(args: argparse.Namespace) -> dict:
    check_slug(args.slug)
    out = evidence_dir(args.slug, args.out_dir) / "test-results.txt"
    raw_path = Path(args.raw)
    if not raw_path.is_absolute():
        raw_path = ROOT / raw_path
    if not raw_path.exists():
        fail(f"raw transcript not found: {raw_path}")

    counts = junit_counts(args.junit)
    lines = raw_path.read_text(encoding="utf-8-sig").splitlines()
    default_strip = ["rootdir:", "generated xml file:", "platform win32 --"]
    strip = default_strip + list(args.strip or [])
    lines = [line for line in lines if not any(needle in line for needle in strip)]

    if not args.no_redact:
        replacements = sorted({str(ROOT), str(Path.home())}, key=len, reverse=True)
        lines = [_redact(line, replacements) for line in lines]

    header: list[str] = []
    if args.header:
        header_path = Path(args.header)
        if not header_path.is_absolute():
            header_path = ROOT / header_path
        if not header_path.exists():
            fail(f"header file not found: {header_path}")
        header = header_path.read_text(encoding="utf-8").splitlines()
    else:
        header = [f"Publication verification — {date.today().isoformat()}"]
        if counts:
            header.append(
                f"Result: {counts['passed']} passed, {counts['skipped']} skipped, "
                f"{counts['failures']} failed, {counts['errors']} errors"
            )
        if args.command:
            header.append(f"Command: {args.command}")
        header.append("Local filesystem paths redacted.")

    write_text(out, "\n".join(header + [""] + lines) + "\n")
    print(f"wrote {display_path(out)} ({out.stat().st_size:,} bytes)")
    if counts:
        print(
            f"result: {counts['passed']} passed, {counts['skipped']} skipped, "
            f"{counts['failures']} failed, {counts['errors']} errors"
        )
    return counts or {}


def _redact(line: str, replacements: list[str]) -> str:
    for value in replacements:
        line = line.replace(value, "<local>")
    return line


def cmd_manifest(args: argparse.Namespace) -> None:
    check_slug(args.slug)
    out_dir = evidence_dir(args.slug, args.out_dir)
    if not out_dir.is_dir():
        fail(f"evidence directory not found: {out_dir}")
    config = read_config(args.config)
    counts = junit_counts(args.junit)
    result = None
    if counts:
        result = {
            "passed": counts["passed"],
            "skipped": counts["skipped"],
            "failed": counts["failures"],
            "errors": counts["errors"],
        }
    elif config.get("result"):
        result = config["result"]

    artifacts = []
    for file in walk_files(out_dir):
        if file.name == "manifest.json":
            continue
        artifacts.append(
            {
                "path": file.relative_to(out_dir).as_posix(),
                "sha256": sha256(file),
                "bytes": file.stat().st_size,
            }
        )

    manifest = {
        "run_id": config.get("run_id") or f"{date.today().strftime('%Y%m%d')}-{args.slug}",
        "recorded_at_utc": config.get("recorded_at_utc")
        or datetime.now(timezone.utc).isoformat(),
        "source_snapshot": config.get("source_snapshot"),
        "source_commit": config.get("source_commit"),
        "source_commit_note": config.get("source_commit_note"),
        "result": result,
        "skips": config.get("skips", []),
        "claims": config.get("claims", {}),
        "limits": config.get("limits", []),
        "artifacts": artifacts,
    }
    out = Path(args.out) if args.out else out_dir / "manifest.json"
    if not out.is_absolute():
        out = ROOT / out
    write_text(out, json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    try:
        display = out.relative_to(ROOT)
    except ValueError:
        display = out
    print(f"wrote {display} with {len(artifacts)} artifact(s)")


def cmd_verify(args: argparse.Namespace) -> int:
    check_slug(args.slug)
    out_dir = evidence_dir(args.slug, args.out_dir)
    manifest_path = out_dir / "manifest.json"
    if not manifest_path.exists():
        fail(f"manifest not found: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    errors: list[str] = []
    warnings: list[str] = []

    if isinstance(manifest.get("artifacts"), list):
        listed = set()
        for artifact in manifest["artifacts"]:
            rel = artifact.get("path")
            if not rel:
                errors.append("artifact entry without a path")
                continue
            listed.add(rel)
            file = out_dir / rel
            if not file.is_file():
                errors.append(f"missing artifact: {rel}")
                continue
            if artifact.get("bytes") is not None and file.stat().st_size != artifact["bytes"]:
                errors.append(f"size mismatch: {rel}")
            if artifact.get("sha256") and sha256(file) != artifact["sha256"].lower():
                errors.append(f"hash mismatch: {rel}")
        actual = {file.relative_to(out_dir).as_posix() for file in walk_files(out_dir)}
        actual.discard("manifest.json")
        for rel in sorted(actual - listed):
            errors.append(f"unlisted evidence file: {rel}")

    if isinstance(manifest.get("files"), list):
        for entry in manifest["files"]:
            rel = entry.get("file")
            if not rel:
                errors.append("files entry without a file path")
                continue
            file = out_dir / rel
            if not file.is_file():
                errors.append(f"missing file: {rel}")
                continue
            expected = entry.get("publication_sha256")
            if expected and sha256(file) != expected.lower():
                errors.append(f"publication hash mismatch: {rel}")

    claims = manifest.get("claims") or {}
    for name, target in claims.items():
        if not isinstance(target, str) or "::" not in target:
            continue
        rel, test_name = target.split("::", 1)
        excerpt = out_dir / rel
        if not excerpt.exists():
            warnings.append(f"claim '{name}' points outside the public excerpts: {rel}")
            continue
        text = excerpt.read_text(encoding="utf-8", errors="replace")
        if not re.search(rf"(?:async\s+)?def\s+{re.escape(test_name)}\s*\(", text):
            errors.append(f"claim '{name}' test not found in {rel}: {test_name}")

    for issue in warnings:
        print(f"WARN  {issue}")
    for issue in errors:
        print(f"ERROR {issue}")
    if errors:
        print(f"\n{args.slug}: {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"{args.slug}: OK ({len(manifest.get('artifacts', []))} artifact(s), {len(claims)} claim(s))")
    return 0


def cmd_finalize(args: argparse.Namespace) -> int:
    transcript_args = argparse.Namespace(
        slug=args.slug,
        raw=args.raw,
        junit=args.junit,
        header=args.header,
        command=args.command,
        out=None,
        out_dir=args.out_dir,
        strip=args.strip,
        no_redact=args.no_redact,
    )
    manifest_args = argparse.Namespace(
        slug=args.slug,
        config=args.config,
        junit=args.junit,
        out=None,
        out_dir=args.out_dir,
    )
    verify_args = argparse.Namespace(slug=args.slug, out_dir=args.out_dir)
    cmd_transcript(transcript_args)
    cmd_manifest(manifest_args)
    return cmd_verify(verify_args)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Evidence toolkit for gcp-architect-blog")
    sub = parser.add_subparsers(dest="command", required=True)

    bundle = sub.add_parser("bundle", help="build a source ZIP and copy excerpts")
    bundle.add_argument("--slug", required=True)
    bundle.add_argument("--source", required=True)
    bundle.add_argument("--zip-name")
    bundle.add_argument("--notes")
    bundle.add_argument("--excerpts", default="")
    bundle.add_argument("--manifest-name", default="MANIFEST.sha256")
    bundle.add_argument("--out-dir")
    bundle.add_argument("--force", action="store_true")
    bundle.set_defaults(func=cmd_bundle)

    transcript = sub.add_parser("transcript", help="normalise a pytest transcript")
    transcript.add_argument("--slug", required=True)
    transcript.add_argument("--raw", required=True)
    transcript.add_argument("--junit")
    transcript.add_argument("--header")
    transcript.add_argument("--command")
    transcript.add_argument("--out-dir")
    transcript.add_argument("--strip", action="append", default=[])
    transcript.add_argument("--no-redact", action="store_true")
    transcript.set_defaults(func=cmd_transcript)

    manifest = sub.add_parser("manifest", help="write manifest.json from the evidence directory")
    manifest.add_argument("--slug", required=True)
    manifest.add_argument("--config")
    manifest.add_argument("--junit")
    manifest.add_argument("--out")
    manifest.add_argument("--out-dir")
    manifest.set_defaults(func=cmd_manifest)

    finalize = sub.add_parser("finalize", help="transcript + manifest + verify")
    finalize.add_argument("--slug", required=True)
    finalize.add_argument("--raw", required=True)
    finalize.add_argument("--junit")
    finalize.add_argument("--header")
    finalize.add_argument("--command")
    finalize.add_argument("--config")
    finalize.add_argument("--out-dir")
    finalize.add_argument("--strip", action="append", default=[])
    finalize.add_argument("--no-redact", action="store_true")
    finalize.set_defaults(func=cmd_finalize)

    verify = sub.add_parser("verify", help="verify manifest hashes and claim tests")
    verify.add_argument("--slug", required=True)
    verify.add_argument("--out-dir")
    verify.set_defaults(func=cmd_verify)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    result = args.func(args)
    return result if isinstance(result, int) else 0


if __name__ == "__main__":
    raise SystemExit(main())
