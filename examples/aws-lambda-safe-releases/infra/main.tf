provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  artifact_bucket_name = "${var.project}-${var.environment}-${local.account_id}"

  # Reuse a shared provider when supplied; otherwise create one owned by this stack.
  oidc_provider_arn = coalesce(
    var.existing_oidc_provider_arn,
    one(aws_iam_openid_connect_provider.github[*].arn),
  )

  codedeploy_arn_prefix = "arn:aws:codedeploy:${local.region}:${local.account_id}"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "demo"
  }
}

# ---------------------------------------------------------------------------
# Artifact storage
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifact_bucket_name
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-demo-artifacts"
    status = "Enabled"
    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

# ---------------------------------------------------------------------------
# Runtime identity: identity policy plus a permissions boundary that caps it
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lambda_boundary" {
  name        = "${var.function_name}-boundary"
  description = "Maximum permissions for the demo runtime: own logs only."
  tags        = local.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteOwnLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
    ]
  })
}

resource "aws_iam_role" "lambda" {
  name                 = "${var.function_name}-runtime"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume.json
  permissions_boundary = aws_iam_policy.lambda_boundary.arn
  tags                 = local.tags
}

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "${var.function_name}-logs"
  role   = aws_iam_role.lambda.id
  policy = aws_iam_policy.lambda_boundary.policy
}

# ---------------------------------------------------------------------------
# Function, stable alias and release alarm
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "app" {
  function_name = var.function_name
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "handler.handler"
  memory_size   = 128
  timeout       = 5
  publish       = true

  filename         = "${path.module}/${var.baseline_zip_path}"
  source_code_hash = filebase64sha256("${path.module}/${var.baseline_zip_path}")

  environment {
    variables = {
      RELEASE_LABEL = "baseline"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda_logs,
  ]

  lifecycle {
    # CodeDeploy owns code and versions after bootstrap. Without this, a later
    # apply would republish the baseline over a candidate or a rolled-back release.
    ignore_changes = [filename, source_code_hash]
  }

  tags = local.tags
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Stable alias used by CodeDeploy for traffic shifting"
  function_name    = aws_lambda_function.app.function_name
  function_version = aws_lambda_function.app.version

  lifecycle {
    # CodeDeploy owns routing after creation. Keep this list narrow and explained.
    ignore_changes = [function_version, routing_config]
  }
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${var.function_name}-live-errors"
  alarm_description   = "Invocation errors on the live alias; drives CodeDeploy automatic rollback."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  datapoints_to_alarm = var.alarm_evaluation_periods
  threshold           = var.alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
    Resource     = "${aws_lambda_function.app.function_name}:live"
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# CodeDeploy: canary with automatic rollback on the alarm above
# ---------------------------------------------------------------------------

resource "aws_codedeploy_app" "app" {
  name             = var.function_name
  compute_platform = "Lambda"
  tags             = local.tags
}

resource "aws_iam_role" "codedeploy" {
  name = "${var.function_name}-codedeploy"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

data "aws_iam_policy_document" "codedeploy_artifacts" {
  statement {
    sid       = "ReadArtifactObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    sid       = "ListArtifactBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.artifacts.arn]
  }
}

resource "aws_iam_role_policy" "codedeploy_artifacts" {
  name   = "${var.function_name}-codedeploy-artifacts"
  role   = aws_iam_role.codedeploy.id
  policy = data.aws_iam_policy_document.codedeploy_artifacts.json
}

resource "aws_codedeploy_deployment_group" "app" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${var.function_name}-canary"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent10Minutes"

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.errors.alarm_name]
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Minimal HTTP API so the weighted split is visible in evidence
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.function_name}-api"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.live.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 20
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  qualifier     = aws_lambda_alias.live.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC deploy role (no long-lived keys)
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count = var.existing_oidc_provider_arn == null ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
  tags = local.tags
}

data "aws_iam_policy_document" "deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.function_name}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "ListArtifacts"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn]
  }

  statement {
    sid       = "ReadWriteArtifacts"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    sid    = "CodeDeployInThisAccount"
    effect = "Allow"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeploymentGroup",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:ListDeployments",
    ]
    resources = [
      "${local.codedeploy_arn_prefix}:application:${aws_codedeploy_app.app.name}",
      "${local.codedeploy_arn_prefix}:deploymentgroup:${aws_codedeploy_app.app.name}/${aws_codedeploy_deployment_group.app.deployment_group_name}",
      "${local.codedeploy_arn_prefix}:deploymentconfig:CodeDeployDefault.LambdaCanary10Percent10Minutes",
      "${local.codedeploy_arn_prefix}:deploymentconfig:CodeDeployDefault.LambdaAllAtOnce",
      "${local.codedeploy_arn_prefix}:deployment:*",
    ]
  }

  statement {
    sid    = "ReadLambdaReleaseState"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetAlias",
      "lambda:ListVersionsByFunction",
    ]
    resources = [
      aws_lambda_function.app.arn,
      "${aws_lambda_function.app.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.function_name}-deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# ---------------------------------------------------------------------------
# Tag-scoped budget guardrail
# ---------------------------------------------------------------------------
# Requires the `Project` tag to be active as a cost-allocation tag:
#   aws ce update-cost-allocation-tags-status \
#     --cost-allocation-tags-status TagKey=Project,Status=Active
# Cost data can lag by up to 24 hours, so this is a guardrail for retained
# resources and future runs, not an instantaneous cap.

resource "aws_budgets_budget" "demo" {
  name         = "${var.project}-demo"
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  tags         = local.tags

  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Project$%s", var.project)]
  }

  dynamic "notification" {
    for_each = [20, 50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = tostring(notification.value)
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_email]
    }
  }
}
