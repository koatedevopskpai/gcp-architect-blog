#!/usr/bin/env bash
# Capture CLI-obtainable evidence for the SLO post, then hand off to the
# screenshot drop zone for the console-only artifacts (SLO burn, alert firing).
#
#   ./capture-evidence.sh [project] [region] [service] [rate] [duration]
#
# Defaults: gcp-architect-demo-2026 us-central1 slo-demo 50 180s
#
# Writes text/JSON into public/evidence/slos-for-cloud-run/ and drives the
# baseline -> burn -> recovery load phases with loadgen/loadgen.sh.
# Requires: gcloud (authenticated), curl, hey, and `terraform apply` already done.

set -euo pipefail

PROJECT="${1:-gcp-architect-demo-2026}"
REGION="${2:-us-central1}"
SERVICE="${3:-slo-demo}"
RATE="${4:-50}"
DURATION="${5:-180s}"

# Attribute gcloud's API quota/usage to the target project, so a stale ADC
# quota project ("project ... does not match quota project ...") can't bite.
export CLOUDSDK_BILLING_QUOTA_PROJECT="$PROJECT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
EVID="$REPO_ROOT/public/evidence/slos-for-cloud-run"
mkdir -p "$EVID"
echo "Evidence dir: $EVID"

# ---------------------------------------------------------------------------
# 1. Service pointer + health check
# ---------------------------------------------------------------------------
URL="$(gcloud run services describe "$SERVICE" \
  --region "$REGION" --project "$PROJECT" --format='value(status.url)')"
echo "$URL" > "$EVID/service-url.txt"
echo "Service URL: $URL"

{
  echo "HTTP $(curl -s -o /dev/null -w '%{http_code}' "$URL/health") - $URL/health ($(date -u +%FT%TZ))"
  echo "body: $(curl -s "$URL/health")"
} | tee "$EVID/health-check.txt"

# ---------------------------------------------------------------------------
# 2. Service + revision + alert-policy definitions (redact before publishing)
# ---------------------------------------------------------------------------
gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" \
  --format json > "$EVID/service-describe.json"

gcloud run revisions list --service "$SERVICE" --region "$REGION" --project "$PROJECT" \
  > "$EVID/revisions.txt"

# Alert policies (burn tiers). `gcloud monitoring policies` is GA; SLO
# definitions themselves are console-only here — see SCREENSHOTS.md.
gcloud monitoring policies list --project "$PROJECT" --format json \
  > "$EVID/alert-policies.json" 2>/dev/null \
  || echo "note: 'gcloud monitoring policies list' unavailable — capture alert policies via console" \
       > "$EVID/alert-policies.json"

# ---------------------------------------------------------------------------
# 3. Drive the burn and record the run window + load output
# ---------------------------------------------------------------------------
RUN_FILE="$EVID/load-run.txt"
{
  echo "# SLO burn run — $(date -u +%FT%TZ)"
  echo "# service=$SERVICE region=$REGION rate=${RATE}rps phase=${DURATION}"
  echo "# NOTE: paste the fast-burn alert firing + resolve timestamps (from your"
  echo "#       inbox / alert incidents) below the summary when captured."
} > "$RUN_FILE"

echo "== driving baseline -> burn -> recovery (see loadgen/loadgen.sh)"
"$SCRIPT_DIR/loadgen/loadgen.sh" "$URL" "$RATE" "$DURATION" 2>&1 | tee -a "$RUN_FILE"

{
  echo
  echo "# captured $(date -u +%FT%TZ)"
  echo "# SLO burn at end of recovery window:"
  echo "#   1h burn = <fill from console>   (expect near 0 after recovery)"
} >> "$RUN_FILE"

# ---------------------------------------------------------------------------
# 4. Cost note template (fill after the billing line appears; billing lags ~1d)
# ---------------------------------------------------------------------------
if [ ! -f "$EVID/cost-note.txt" ]; then
  cat > "$EVID/cost-note.txt" <<'EOF'
Window: Cloud Run slo-demo, scale-to-zero, client-side load burst only (no VM).
Expected total: <$1 for the run-and-capture session.
TODO: paste the actual billing line for the run window, then confirm teardown.
EOF
fi

# ---------------------------------------------------------------------------
# 5. Teardown reminder
# ---------------------------------------------------------------------------
echo
echo "Capture the console screenshots listed in:"
echo "  $EVID/SCREENSHOTS.md"
echo
echo "Then tear down (same day):"
echo "  terraform destroy -var=\"project_id=$PROJECT\""
echo
echo "Done. Files written to $EVID"
