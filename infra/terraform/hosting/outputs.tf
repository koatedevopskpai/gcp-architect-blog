output "project_id" {
  value = google_project.blog.project_id
}

output "project_number" {
  value = google_project.blog.number
}

output "default_url" {
  description = "Firebase Hosting default URL (set this as `site` in astro.config.mjs)"
  value       = "https://${google_project.blog.project_id}.web.app"
}

output "ci_workload_identity_provider" {
  description = "Provider resource name for google-github-actions/auth"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account_email" {
  description = "Service account impersonated by GitHub Actions"
  value       = google_service_account.deploy.email
}
