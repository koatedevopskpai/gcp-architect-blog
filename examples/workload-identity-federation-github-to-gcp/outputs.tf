output "workload_identity_provider" {
  description = "Full provider resource name for google-github-actions/auth"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Service account email for google-github-actions/auth"
  value       = google_service_account.github_ci.email
}

output "auth_snippet" {
  description = "Copy/paste values for the GitHub Actions auth step"
  value = {
    workload_identity_provider = google_iam_workload_identity_pool_provider.github.name
    service_account            = google_service_account.github_ci.email
  }
}
