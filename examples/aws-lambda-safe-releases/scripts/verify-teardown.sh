#!/usr/bin/env bash
# Verify that demo resources are gone. Tag discovery supplements service-level
# checks; neither alone proves that nothing survived.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/common.sh"
aws_bin="$(resolve_aws)"
aws() { "$aws_bin" "$@"; }

project="${PROJECT:-aws-lambda-safe-releases}"
region="${AWS_REGION:-eu-west-2}"

echo "== Tagged resources =="
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Project,Values=${project}" \
  --region "$region" \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output table || true

echo "== Lambda functions =="
aws lambda list-functions --region "$region" \
  --query "Functions[?starts_with(FunctionName, '${project}')].FunctionName" \
  --output table

echo "== CodeDeploy applications =="
aws deploy list-applications --region "$region" \
  --query "applications[?starts_with(@, '${project}')]" \
  --output table

echo "== CloudWatch alarms =="
aws cloudwatch describe-alarms --region "$region" \
  --query "MetricAlarms[?starts_with(AlarmName, '${project}')].AlarmName" \
  --output table

echo "== API Gateway v2 APIs =="
aws apigatewayv2 get-apis --region "$region" \
  --query "Items[?starts_with(Name, '${project}')].Name" \
  --output table

echo "== IAM policies =="
aws iam list-policies --scope Local \
  --query "Policies[?starts_with(PolicyName, '${project}')].PolicyName" \
  --output table

echo "== Log groups =="
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/${project}" --region "$region" \
  --query 'logGroups[].logGroupName' \
  --output table

echo "== S3 buckets =="
aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, '${project}')].Name" \
  --output table

echo "== IAM roles =="
aws iam list-roles \
  --query "Roles[?starts_with(RoleName, '${project}')].RoleName" \
  --output table
