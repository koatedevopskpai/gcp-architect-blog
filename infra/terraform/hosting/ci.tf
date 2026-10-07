# --- Keyless CI: Workload Identity Federation for GitHub Actions ---
# The blog deploys itself using the exact pattern its first post teaches.
# Note: org policy iam.disableServiceAccountKeyCreation makes WIF the only option.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions pool"
  description               = "Federated identities for building and deploying the blog"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Security boundary: only this repository may federate.
  attribute_condition = "assertion.repository == 'koatedevopskpai/gcp-architect-blog'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# The deploy identity impersonated by GitHub Actions. No key can exist (org policy).
resource "google_service_account" "deploy" {
  account_id   = "gh-actions-deploy"
  display_name = "GitHub Actions deploy (blog)"
  description  = "Impersonated by GitHub Actions via WIF to deploy Firebase Hosting"
}

locals {
  deploy_roles = [
    "roles/firebasehosting.admin",
    "roles/firebase.viewer",
  ]
}

resource "google_project_iam_member" "deploy" {
  for_each = toset(local.deploy_roles)

  project = google_project.blog.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

# Bind the repository principal to the deploy SA.
resource "google_service_account_iam_member" "wif_deploy" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/koatedevopskpai/gcp-architect-blog"
}