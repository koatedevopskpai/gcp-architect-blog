#!/usr/bin/env bash
# Capture machine-readable release state into evidence/raw/<run-id>/.
# Raw evidence is gitignored; redact before publishing anything.
#
# Usage:
#   ./scripts/collect-evidence.sh
#   DEPLOYMENT_ID=d-XXXX ./scripts/collect-evidence.sh
set -euo pipefail

run_id="${RUN_ID:-$(date -u +%Y%m%d-%H%M)}"
function_name="${FUNCTION_NAME:-aws-lambda-safe-releases}"
alias_name="${ALIAS_NAME:-live}"
app_name="${CODEDEPLOY_APP:-$function_name}"
group_name="${CODEDEPLOY_GROUP:-$function_name-canary}"
region="${AWS_REGION:-eu-west-2}"
deployment_id="${DEPLOYMENT_ID:-}"

root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/scripts/common.sh"
aws_bin="$(resolve_aws)"
aws() { "$aws_bin" "$@"; }
out="$root/evidence/raw/$run_id"
mkdir -p "$out"

{
  echo "run_id=$run_id"
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "region=$region"
  echo "commit=$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "function_name=$function_name"
  echo "alias_name=$alias_name"
  echo "deployment_id=$deployment_id"
} > "$out/run-meta.txt"

aws lambda get-function --function-name "$function_name" --region "$region" > "$out/lambda-function.json"
aws lambda get-alias --function-name "$function_name" --name "$alias_name" --region "$region" > "$out/lambda-alias.json"
aws lambda list-versions-by-function --function-name "$function_name" --region "$region" > "$out/lambda-versions.json"
aws deploy get-application --application-name "$app_name" --region "$region" > "$out/codedeploy-app.json" 2>/dev/null || true
aws deploy get-deployment-group --application-name "$app_name" --deployment-group-name "$group_name" --region "$region" > "$out/codedeploy-group.json" 2>/dev/null || true
aws deploy list-deployments --application-name "$app_name" --deployment-group-name "$group_name" --region "$region" > "$out/codedeploy-deployments.json"
aws cloudwatch describe-alarms --alarm-names "${function_name}-live-errors" --region "$region" > "$out/alarms.json"
aws apigatewayv2 get-apis --region "$region" > "$out/apis.json"
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/${function_name}" --region "$region" > "$out/log-groups.json"

if [ -n "$deployment_id" ]; then
  aws deploy get-deployment --deployment-id "$deployment_id" --region "$region" > "$out/deployment.json"
fi

echo "wrote $out"
