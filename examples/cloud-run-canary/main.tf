# Companion example: Cloud Run canary (post 012).
#
# Scaffold only: validate this configuration, then run it against a disposable
# project. See README.md for the phases and the honest evidence boundary.

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
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "service_name" {
  type    = string
  default = "canary-demo"
}

variable "artifact_repo" {
  type    = string
  default = "canary-images"
}

variable "image" {
  description = "Container image for the first revision. The release pipeline takes over afterwards."
  type        = string
}

variable "server_error_rate_threshold" {
  description = "5xx requests per second across the service that triggers the starter alert."
  type        = number
  default     = 0.1
}

variable "alert_email" {
  description = "Optional email for the starter 5xx alert. Empty disables the channel."
  type        = string
  default     = ""
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Attribute quota/usage to the target project rather than the ADC default.
  user_project_override = true
  billing_project       = var.project_id

  default_labels = {
    project     = var.project_id
    environment = "demo"
    managed_by  = "terraform"
    workload    = "blog12-cloud-run-canary"
    cost_center = "cc-gcp-platform"
  }
}

locals {
  services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "cloudbuild.googleapis.com",
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.services)

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# ---------------------------------------------------------------------------
# 1. Artifact Registry + runtime identity
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = var.artifact_repo
  description   = "Canary demo image"
  format        = "DOCKER"

  labels = {
    finops_owner = "platform"
    env          = "demo"
  }

  depends_on = [google_project_service.services]
}

resource "google_service_account" "run" {
  account_id   = "canary-demo-sa"
  display_name = "Cloud Run canary demo runtime"
  description  = "Runtime identity for the canary demo service"

  depends_on = [google_project_service.services]
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.run.email}"
}

# ---------------------------------------------------------------------------
# 2. The service
#
# Terraform owns the service shape (identity, probes, resources). After the
# first apply, the image and traffic fields belong to the release pipeline:
# both are ignored so a later `terraform apply` does not undo a canary step.
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "app" {
  name                = var.service_name
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.run.email

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "FAIL_MODE"
        value = "0"
      }

      startup_probe {
        tcp_socket {
          port = 8080
        }
        initial_delay_seconds = 0
        timeout_seconds       = 5
        period_seconds        = 5
        failure_threshold     = 3
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    timeout = "30s"

    annotations = {
      "run.googleapis.com/startup-cpu-boost"     = "true"
      "run.googleapis.com/execution-environment" = "gen2"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      traffic,
    ]
  }

  depends_on = [
    google_artifact_registry_repository.images,
    google_artifact_registry_repository_iam_member.reader,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------
# 3. Starter alert: service-level 5xx rate
#
# This is deliberately coarse. A canary decision needs revision-scoped metrics
# (group by revision_name); that lives in the dashboard/runbook, not here.
# ---------------------------------------------------------------------------
resource "google_monitoring_notification_channel" "email" {
  count = var.alert_email == "" ? 0 : 1

  display_name = "Canary demo email"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "server_errors" {
  display_name = "${var.service_name} — 5xx request rate"
  combiner     = "OR"

  notification_channels = var.alert_email == "" ? [] : [google_monitoring_notification_channel.email[0].name]

  conditions {
    display_name = "5xx requests per second above ${var.server_error_rate_threshold}"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloud_run_revision\"",
        "resource.label.\"service_name\" = \"${var.service_name}\"",
        "metric.type = \"run.googleapis.com/request_count\"",
        "metric.label.\"response_code_class\" = \"5xx\"",
      ])

      comparison      = "COMPARISON_GT"
      threshold_value = var.server_error_rate_threshold
      duration        = "120s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = []
      }
    }
  }

  depends_on = [google_project_service.services]
}
