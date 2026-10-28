#!/usr/bin/env bash
# Build, publish and deploy one release through CodeDeploy.
#
# For AWS Lambda, a CodeDeploy revision is the AppSpec file, not the code zip.
# This script therefore:
#   1. uploads the code artifact to S3,
#   2. publishes a new Lambda version from it,
#   3. sends CodeDeploy an AppSpecContent revision naming the current and target
#      versions, and lets CodeDeploy shift traffic.
#
# Usage:
#   ARTIFACT_BUCKET=... ./scripts/deploy.sh healthy
#   ARTIFACT_BUCKET=... ./scripts/deploy.sh faulty --wait
#
# Environment (defaults in brackets):
#   FUNCTION_NAME   [aws-lambda-safe-releases]
#   ALIAS_NAME      [live]
#   CODEDEPLOY_APP  [$FUNCTION_NAME]
#   CODEDEPLOY_GROUP[$FUNCTION_NAME-canary]
#   AWS_REGION      [eu-west-2]
#
# Deployment config:
#   healthy/baseline -> CodeDeployDefault.LambdaAllAtOnce
#   faulty           -> CodeDeployDefault.LambdaCanary10Percent10Minutes
# Override with --config <name>.
set -euo pipefail

release="${1:-}"
if [ -z "$release" ]; then
  echo "usage: $0 <baseline|healthy|faulty> [--config NAME] [--wait]" >&2
  exit 2
fi
shift

config=""
wait_for="false"
while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      config="${2:?--config needs a value}"
      shift 2
      ;;
    --wait)
      wait_for="true"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

function_name="${FUNCTION_NAME:-aws-lambda-safe-releases}"
alias_name="${ALIAS_NAME:-live}"
app_name="${CODEDEPLOY_APP:-$function_name}"
group_name="${CODEDEPLOY_GROUP:-$function_name-canary}"
bucket="${ARTIFACT_BUCKET:?set ARTIFACT_BUCKET to the Terraform artifact_bucket output}"
region="${AWS_REGION:-eu-west-2}"

if [ -z "$config" ]; then
  case "$release" in
    faulty) config="CodeDeployDefault.LambdaCanary10Percent10Minutes" ;;
    *)      config="CodeDeployDefault.LambdaAllAtOnce" ;;
  esac
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/scripts/common.sh"

python_bin="$(resolve_python)"
aws_bin="$(resolve_aws)"
aws() { "$aws_bin" "$@"; }

# Build and upload the code artifact.
artifact="$("$python_bin" "$root/scripts/build.py" "$release")"
key="releases/${release}.zip"

# aws.exe on Windows cannot read a WSL path such as /mnt/c/...; convert it.
aws_artifact="$artifact"
if command -v wslpath >/dev/null 2>&1; then
  aws_artifact="$(wslpath -w "$artifact")"
elif command -v cygpath >/dev/null 2>&1; then
  aws_artifact="$(cygpath -w "$artifact")"
fi

aws s3 cp "$aws_artifact" "s3://${bucket}/${key}" --region "$region" >/dev/null
echo "uploaded s3://${bucket}/${key}"

current_version="$(aws lambda get-alias \
  --function-name "$function_name" \
  --name "$alias_name" \
  --region "$region" \
  --query 'FunctionVersion' \
  --output text | tr -d '\r')"

# Publish the new version from the uploaded code. The alias stays on
# current_version until CodeDeploy shifts traffic.
target_version="$(aws lambda update-function-code \
  --function-name "$function_name" \
  --s3-bucket "$bucket" \
  --s3-key "$key" \
  --publish \
  --region "$region" \
  --query 'Version' \
  --output text | tr -d '\r')"

echo "current_version=${current_version}"
echo "target_version=${target_version}"

appspec="$root/build/appspec-${release}.yaml"
cat > "$appspec" <<EOF
version: 0.0
Resources:
  - myLambdaFunction:
      Type: AWS::Lambda::Function
      Properties:
        Name: "${function_name}"
        Alias: "${alias_name}"
        CurrentVersion: "${current_version}"
        TargetVersion: "${target_version}"
EOF

revision_json="$("$python_bin" - "$appspec" <<'PY'
import json
import sys

content = open(sys.argv[1], encoding="utf-8").read()
print(json.dumps({
    "revisionType": "AppSpecContent",
    "appSpecContent": {"content": content},
}))
PY
)"

deployment_id="$(aws deploy create-deployment \
  --application-name "$app_name" \
  --deployment-group-name "$group_name" \
  --deployment-config-name "$config" \
  --revision "$revision_json" \
  --region "$region" \
  --query 'deploymentId' \
  --output text | tr -d '\r')"

echo "deployment_id=${deployment_id}"
echo "config=${config}"

if [ "$wait_for" = "true" ]; then
  aws deploy wait deployment-successful --deployment-id "$deployment_id" --region "$region"
  echo "deployment succeeded"
fi
