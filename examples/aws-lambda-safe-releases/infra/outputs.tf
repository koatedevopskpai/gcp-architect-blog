output "api_url" {
  description = "Invoke URL for the demo HTTP API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "function_name" {
  value = aws_lambda_function.app.function_name
}

output "alias_name" {
  value = aws_lambda_alias.live.name
}

output "deployment_group" {
  value = aws_codedeploy_deployment_group.app.deployment_group_name
}

output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.errors.alarm_name
}

output "deploy_role_arn" {
  description = "Set this as the AWS_DEPLOY_ROLE_ARN secret in GitHub."
  value       = aws_iam_role.deploy.arn
}

output "oidc_provider_arn" {
  description = "Shared or stack-owned GitHub OIDC provider."
  value       = local.oidc_provider_arn
}
