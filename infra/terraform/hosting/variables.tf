variable "project_id" {
  description = "New GCP project id for the blog (also the default Firebase Hosting site id)"
  type        = string
  default     = "gcp-architect-blog"
}

variable "project_name" {
  description = "Human-readable project name"
  type        = string
  default     = "GCP Architect Blog"
}

variable "org_id" {
  description = "GCP organization id to create the project under"
  type        = string
}

variable "billing_account_id" {
  description = "Billing account id to link"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "budget_gbp" {
  description = "Monthly hard budget cap for the blog project (GBP)"
  type        = number
  default     = 2
}

# --- FinOps labels ---
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
