output "service_url" {
  value = google_cloud_run_v2_service.svc.uri
}

output "image" {
  description = "Resolved image the service runs (push here before the full apply)."
  value       = local.image
}

output "artifact_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo}"
}

output "availability_slo" {
  value = google_monitoring_slo.availability.name
}

output "latency_slo" {
  value = google_monitoring_slo.latency.name
}

output "dashboard_id" {
  value = google_monitoring_dashboard.svc.id
}

output "page_channel" {
  value = google_monitoring_notification_channel.page.name
}

output "ticket_channel" {
  value = google_monitoring_notification_channel.ticket.name
}
