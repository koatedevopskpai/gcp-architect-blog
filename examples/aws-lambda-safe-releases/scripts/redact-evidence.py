#!/usr/bin/env python3
"""Copy raw evidence into a publishable directory with basic redactions.

Usage:
    python scripts/redact-evidence.py evidence/raw/<run-id> \
        --out public/evidence/aws-lambda-safe-releases/<run-id>

Text artifacts are copied with substitutions. Images, video and archives are
NOT copied: they need manual review because pixel data cannot be redacted
safely by this script. The report lists every file it skipped.

Run from the example root. The output directory must not already exist unless
--force is supplied.
"""

from __future__ import annotations

import argparse
import re
import shutil
from collections import Counter
from pathlib import Path

ACCOUNT_ID = re.compile(r"\b\d{12}\b")
ARN = re.compile(r"(arn:aws[a-z-]*:[a-z0-9-]+:[a-z0-9-]*:)\d{12}(:)")
EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
ACCESS_KEY = re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")

SUBSTITUTIONS = [
    (ARN, r"\1<account>\2"),
    (ACCOUNT_ID, "<account>"),
    (EMAIL, "<email>"),
    (ACCESS_KEY, "<redacted-access-key>"),
]

TEXT_SUFFIXES = {".json", ".txt", ".log", ".md", ".yaml", ".yml", ".csv"}
BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".mp4", ".zip", ".pdf"}


def redact(text: str) -> tuple[str, Counter]:
    counts: Counter = Counter()
    for pattern, replacement in SUBSTITUTIONS:
        text, n = pattern.subn(replacement, text)
        if n:
            counts[pattern.pattern] += n
    return text, counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    if not args.source.is_dir():
        raise SystemExit(f"source is not a directory: {args.source}")
    if args.out.exists() and not args.force:
        raise SystemExit(f"output exists: {args.out} (use --force to overwrite)")

    if args.out.exists():
        shutil.rmtree(args.out)
    args.out.mkdir(parents=True)

    copied = 0
    skipped: list[str] = []
    totals: Counter = Counter()

    for source in sorted(args.source.rglob("*")):
        if not source.is_file():
            continue
        relative = source.relative_to(args.source)
        suffix = source.suffix.lower()

        if suffix in TEXT_SUFFIXES or suffix == "":
            text = source.read_text(encoding="utf-8", errors="replace")
            cleaned, counts = redact(text)
            destination = args.out / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(cleaned, encoding="utf-8")
            totals.update(counts)
            copied += 1
        elif suffix in BINARY_SUFFIXES:
            skipped.append(str(relative))
        else:
            skipped.append(str(relative))

    report = [
        "# Redaction report",
        "",
        f"Source: `{args.source}`",
        f"Output: `{args.out}`",
        "",
        f"Text files copied: **{copied}**",
        f"Files skipped (manual review required): **{len(skipped)}**",
        "",
        "## Substitutions",
        "",
        *([f"- `{pattern}`: {count}" for pattern, count in totals.items()] or ["- none"]),
        "",
        "## Skipped",
        "",
        *([f"- `{name}`" for name in skipped] or ["- none"]),
        "",
        "Images and video are never copied automatically. Review them by hand, or",
        "crop/redact them before adding them to the publishable evidence directory.",
    ]
    (args.out / "REDACTION_REPORT.md").write_text("\n".join(report) + "\n", encoding="utf-8")

    print(f"Copied {copied} text file(s); skipped {len(skipped)} for manual review")
    print(f"Report: {args.out / 'REDACTION_REPORT.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
