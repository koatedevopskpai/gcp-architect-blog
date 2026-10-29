#!/usr/bin/env bash
# Bounded concurrent load for a canary bake step.
#
# Usage:
#   DURATION=60 CONCURRENCY=8 ./scripts/load.sh https://canary---canary-demo-....run.app
#
# Writes one HTTP status per line to a temporary file and prints the counts.
# Requires `timeout` (coreutils or macOS `gtimeout`); run this from Linux,
# Cloud Shell, or WSL.
set -euo pipefail

TARGET_URL="${1:?usage: load.sh <target-url> [duration-seconds] [concurrency]}"
DURATION="${2:-${DURATION:-60}}"
CONCURRENCY="${3:-${CONCURRENCY:-8}}"

command -v timeout >/dev/null 2>&1 || {
  echo "timeout not found; install coreutils or run from Cloud Shell/WSL" >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || { echo "curl not found" >&2; exit 1; }

OUT="$(mktemp)"
export TARGET_URL

for _ in $(seq 1 "$CONCURRENCY"); do
  timeout "${DURATION}s" bash -c \
    'while :; do curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 "$TARGET_URL/" || echo "000"; done' \
    >>"$OUT" &
done

wait

echo "status counts (${DURATION}s, ${CONCURRENCY} workers):"
sort "$OUT" | uniq -c | sort -rn
rm -f "$OUT"
