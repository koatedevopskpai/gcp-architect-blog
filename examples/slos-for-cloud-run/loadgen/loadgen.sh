#!/usr/bin/env bash
# Drive a *real* burn against the SLO demo service, then let it recover.
#
#   ./loadgen.sh <service-url> [rate] [duration]
#
# Phase 1 (baseline):  plain 200s so the SLO is green.
# Phase 2 (burn):      a fraction of requests fail (availability burn) and a
#                      fraction are slow (latency burn).
# Phase 3 (recovery):  back to clean traffic; watch the alert resolve.
#
# Requires `hey` (https://github.com/rakyll/hey) — `brew install hey` / `go install`.

set -euo pipefail

URL="${1:?usage: loadgen.sh <service-url> [rate] [duration]}"
RATE="${2:-50}"       # requests per second
DURATION="${3:-180s}" # per phase

echo "== Phase 1: baseline (green) — ${RATE}rps for ${DURATION}"
hey -z "${DURATION}" -q "${RATE}" -c 20 "${URL}/work"

echo "== Phase 2: burn — mixed 500s + slow responses"
# Half fail, half are slow. Run both concurrently for sustained burn.
hey -z "${DURATION}" -q "$((RATE / 2))" -c 20 "${URL}/work?fail=1" &
hey -z "${DURATION}" -q "$((RATE / 2))" -c 20 "${URL}/work?latency_ms=1500" &
wait

echo "== Phase 3: recovery — clean traffic for ${DURATION}"
hey -z "${DURATION}" -q "${RATE}" -c 20 "${URL}/work"

echo "Done. Capture: SLO burn, fast-burn alert firing + recovery, dashboard."
