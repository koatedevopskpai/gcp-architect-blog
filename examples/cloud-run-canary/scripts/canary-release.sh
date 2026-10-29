#!/usr/bin/env bash
# Deploy a candidate Cloud Run revision with no traffic, probe it, then step
# traffic up. Any failed check rolls traffic back to the previous revision.
#
# This is lab tooling, not a production release controller. It works by
# revision name on purpose: `--to-tags` splits the remainder to the newest
# ready revision, which is exactly the revision you are testing when it was
# deployed with --no-traffic.
#
# Usage:
#   IMAGE=... SERVICE=canary-demo REGION=us-central1 \
#     STEPS="1 10 50" BAKE_SECONDS=300 CHECK_CMD="./scripts/check-canary.sh" \
#     ./scripts/canary-release.sh
set -euo pipefail

SERVICE="${SERVICE:-canary-demo}"
REGION="${REGION:-us-central1}"
IMAGE="${IMAGE:?set IMAGE to the candidate image}"
TAG="${TAG:-canary}"
STEPS="${STEPS:-1 10 50}"
BAKE_SECONDS="${BAKE_SECONDS:-300}"
FAIL_MODE="${FAIL_MODE:-0}"
CHECK_CMD="${CHECK_CMD:-}"
AUTO_APPROVE="${AUTO_APPROVE:-0}"

for bin in gcloud curl; do
  command -v "$bin" >/dev/null 2>&1 || { echo "missing dependency: $bin" >&2; exit 1; }
done

describe() {
  gcloud run services describe "$SERVICE" --region "$REGION" --format="$1"
}

PREVIOUS="$(describe 'value(status.latestReadyRevisionName)')"
if [[ -z "$PREVIOUS" ]]; then
  echo "service $SERVICE has no ready revision; apply Terraform first" >&2
  exit 1
fi
echo "previous healthy revision: $PREVIOUS"

PROMOTED=0
rollback() {
  echo "rolling back to $PREVIOUS"
  gcloud run services update-traffic "$SERVICE" \
    --region "$REGION" \
    --to-revisions "$PREVIOUS=100" \
    --quiet
}
on_exit() {
  local status=$?
  if [[ $status -ne 0 && $PROMOTED -eq 0 ]]; then
    echo "release failed (exit $status); attempting rollback" >&2
    rollback || echo "rollback command failed; check the console" >&2
  fi
  exit $status
}
trap on_exit EXIT

echo "deploying $IMAGE with no traffic, tag=$TAG, FAIL_MODE=$FAIL_MODE"
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --no-traffic \
  --tag "$TAG" \
  --set-env-vars "FAIL_MODE=$FAIL_MODE" \
  --quiet

CANDIDATE="$(describe 'value(status.latestReadyRevisionName)')"
if [[ "$CANDIDATE" == "$PREVIOUS" ]]; then
  echo "candidate revision equals the previous revision; refusing to continue" >&2
  exit 1
fi
echo "candidate revision: $CANDIDATE"

CANARY_URL="$(describe 'value(status.traffic[?tag==`'"$TAG"'`].url)' | head -n1)"
if [[ -z "$CANARY_URL" ]]; then
  echo "could not read the tag URL for $TAG" >&2
  exit 1
fi
echo "tag URL: $CANARY_URL"

echo "probing the candidate before any traffic"
curl -fsS --max-time 10 "$CANARY_URL/healthz" >/dev/null
for _ in $(seq 1 20); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$CANARY_URL/version")"
  if [[ "$code" != "200" ]]; then
    echo "candidate returned HTTP $code before traffic; stopping" >&2
    exit 1
  fi
done

for pct in $STEPS; do
  if (( pct <= 0 || pct >= 100 )); then
    echo "invalid step $pct; use a value between 1 and 99" >&2
    exit 1
  fi
  remain=$((100 - pct))
  echo "shifting ${pct}% to $CANDIDATE (${remain}% stays on $PREVIOUS)"
  gcloud run services update-traffic "$SERVICE" \
    --region "$REGION" \
    --to-revisions "$PREVIOUS=$remain,$CANDIDATE=$pct" \
    --quiet

  echo "baking ${BAKE_SECONDS}s at ${pct}%"
  sleep "$BAKE_SECONDS"

  if [[ -n "$CHECK_CMD" ]]; then
    echo "running check: $CHECK_CMD"
    if ! eval "$CHECK_CMD"; then
      echo "check failed at ${pct}%; stopping" >&2
      exit 1
    fi
  fi

  if [[ "$AUTO_APPROVE" != "1" ]]; then
    read -r -p "continue to the next step? [y/N] " answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      echo "stopped by operator at ${pct}%" >&2
      exit 1
    fi
  fi
done

echo "promoting $CANDIDATE to 100%"
gcloud run services update-traffic "$SERVICE" \
  --region "$REGION" \
  --to-revisions "$CANDIDATE=100" \
  --quiet

PROMOTED=1
echo "promoted. previous revision kept for rollback: $PREVIOUS"
echo "rollback: gcloud run services update-traffic $SERVICE --region $REGION --to-revisions $PREVIOUS=100"
