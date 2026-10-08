variable "project_id" {
  description = "Shared demo project for tier-1 proof runs"
  type        = string
  default     = "gcp-architect-demo-2026"
}

variable "project_name" {
  type    = string
  default = "GCP Architect Demo"
}

variable "org_id" {
  type = string
}

variable "billing_account_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "budget_gbp" {
  type    = number
  default = 5
}

variable "cost_center" {
  type    = string
  default = "cc-gcp-platform"
}

variable "business_unit" {
  type    = string
  default = "data-platform"
}

variable "tag_owner" {
  type    = string
  default = "koatekpai"
}