terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to federate, as OWNER/REPO"
  type        = string
}

variable "pool_id" {
  description = "Workload identity pool id"
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "Workload identity pool provider id"
  type        = string
  default     = "github"
}

variable "service_account_id" {
  description = "Service account id impersonated by the workflow"
  type        = string
  default     = "github-ci"
}

variable "project_roles" {
  description = "Project-level roles granted to the CI service account"
  type        = list(string)
  default = [
    "roles/run.admin",
    "roles/artifactregistry.writer",
  ]
}

provider "google" {
  project = var.project_id
}

# ---------------------------------------------------------------------------
# 1. Workload identity pool + GitHub OIDC provider
# ---------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions pool"
  description               = "Federated identities for GitHub Actions CI"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Security boundary: only this repository may federate.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ---------------------------------------------------------------------------
# 2. Least-privilege service account
# ---------------------------------------------------------------------------
resource "google_service_account" "github_ci" {
  account_id   = var.service_account_id
  display_name = "GitHub Actions CI"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation"
}

resource "google_project_iam_member" "github_ci" {
  for_each = toset(var.project_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.github_ci.email}"
}

# The identity the DEPLOYED workload runs as — separate from the CI identity.
resource "google_service_account" "runtime" {
  account_id   = "cloud-run-runtime"
  display_name = "Deployed workload runtime"
}

# The CI SA may deploy a workload that runs as the runtime SA.
# Note: bind this on the RUNTIME SA, not on the CI SA itself.
resource "google_service_account_iam_member" "github_ci_can_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_ci.email}"
}

# ---------------------------------------------------------------------------
# 3. Bind the GitHub repository principal to the service account
# ---------------------------------------------------------------------------
resource "google_service_account_iam_member" "wif_user" {
  service_account_id = google_service_account.github_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
