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
