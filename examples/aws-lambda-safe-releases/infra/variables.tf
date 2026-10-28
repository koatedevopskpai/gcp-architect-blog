variable "aws_region" {
  description = "AWS region for the demonstration."
  type        = string
  default     = "eu-west-2"
}

variable "project" {
  description = "Project tag and resource name prefix."
  type        = string
  default     = "aws-lambda-safe-releases"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "demo"
}

variable "function_name" {
  description = "Lambda function name."
  type        = string
  default     = "aws-lambda-safe-releases"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the function."
  type        = number
  default     = 7
}

variable "baseline_zip_path" {
  description = "Baseline artifact path, relative to the infra directory. Run scripts/build.py first."
  type        = string
  default     = "../build/baseline.zip"
}

variable "existing_oidc_provider_arn" {
  description = "ARN of an existing GitHub OIDC provider. When null, one is created and owned by this stack."
  type        = string
  default     = null
}

variable "github_repo" {
  description = "GitHub owner/repo allowed to assume the deploy role."
  type        = string
  default     = "koatedevopskpai/gcp-architect-blog"
}

variable "github_branch" {
  description = "Branch allowed to assume the deploy role."
  type        = string
  default     = "main"
}

variable "alarm_period_seconds" {
  description = "CloudWatch alarm period. 60s x 2 evaluation periods fits inside the 10-minute canary."
  type        = number
  default     = 60
}

variable "alarm_evaluation_periods" {
  description = "Consecutive periods that must breach before ALARM."
  type        = number
  default     = 2
}

variable "alarm_threshold" {
  description = "Error count threshold per period."
  type        = number
  default     = 1
}

variable "budget_email" {
  description = "Email address for the tag-scoped demo budget notifications."
  type        = string
}
