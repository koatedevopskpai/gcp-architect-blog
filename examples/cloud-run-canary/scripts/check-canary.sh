#!/usr/bin/env bash
# Lab stand-in for a revision-scoped stop condition.
#
# Probes the tagged candidate directly. This does NOT measure the share of
# organic production traffic reaching the candidate; use revision-scoped
# Cloud Monitoring metrics for that. It is here so the release script has a
# real non-zero exit path that can trigger rollback.
#
# Usage:
#   CANARY_URL=https://canary---canary-demo-....run.app SAMPLES=100 MAX_ERRORS=1 \
#     ./scripts/check-canary.sh
set -euo pipefail

CANARY_URL="${CANARY_URL:?set CANARY_URL to the tagged candidate URL}"
SAMPLES="${SAMPLES:-100}"
MAX_ERRORS="${MAX_ERRORS:-1}"

errors=0

for _ in $(seq 1 "$SAMPLES"); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$CANARY_URL/")"
  if [[ "$code" =~ ^5 ]]; then
    errors=$((errors + 1))
  elif [[ "$code" != "200" ]]; then
    echo "unexpected HTTP $code (counting as an error)" >&2
    errors=$((errors + 1))
  fi
done

echo "candidate probe: $errors 5xx/unexpected out of $SAMPLES requests"

if (( errors > MAX_ERRORS )); then
  echo "stop condition met: $errors > $MAX_ERRORS" >&2
  exit 1
fi
