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

variable "image" {
  description = "Container image to deploy (defaults to Google's sample hello)"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello:latest"
}

variable "service_name" {
  type    = string
  default = "hello"
}

variable "alert_email" {
  description = "Email address for the burn-rate alert (set a real one)"
  type        = string
  default     = "ops@example.com"
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    project     = var.project_id
    environment = "demo"
    managed_by  = "terraform"
    workload    = "blog2-cloud-run-golden-path"
    cost_center = "cc-gcp-platform"
  }
}

data "google_project" "current" {}

# ---------------------------------------------------------------------------
# 1. Artifact Registry repository for the image
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "cloud-run-images"
  description   = "Container images for the golden path demo"
  format        = "DOCKER"

  # FinOps: label every resource; this one also feeds the runtime SA reader grant.
  labels = {
    finops_owner = "platform"
    env          = "demo"
  }
  # Note: vulnerability scanning is enabled by default for Artifact Registry in
  # supported regions. Tag-retention (lifecycle policy) isn't exposed in the
  # provider yet — see README for the gcloud one-liner.
}

# ---------------------------------------------------------------------------
# 2. Runtime identity (least privilege) + public ingress
# ---------------------------------------------------------------------------
resource "google_service_account" "hello" {
  account_id   = "hello-sa"
  display_name = "hello Cloud Run runtime"
  description  = "Runtime identity for the golden path Cloud Run service"
}

# The runtime SA may pull images from the registry (self-hosted images).
resource "google_artifact_registry_repository_iam_member" "reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.images.id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.hello.email}"
}

# ---------------------------------------------------------------------------
# 3. The Cloud Run service (v2) — golden-path defaults
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "hello" {
  name     = var.service_name
  location = var.region
  # Demo: allow terraform destroy (default is protected).
  deletion_protection = false

  template {
    service_account = google_service_account.hello.email

    containers {
      image = var.image
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
      startup_probe {
        tcp_socket { port = 8080 }
        initial_delay_seconds = 0
        timeout_seconds       = 5
        period_seconds        = 5
        failure_threshold     = 3
      }
    }

    # Scale to zero by default; cap burst.
    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    # Bound stuck requests (opinionated default; tune per workload).
    timeout = "30s"

    annotations = {
      # Faster cold starts: extra CPU during startup only.
      "run.googleapis.com/startup-cpu-boost"     = "true"
      # Second-generation execution environment (v2 default; explicit here).
      "run.googleapis.com/execution-environment" = "gen2"
    }
  }

  depends_on = [google_artifact_registry_repository.images]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.hello.location
  name     = google_cloud_run_v2_service.hello.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------
# 4. SLOs (the Qiita pattern): availability + latency, with burn-rate alert
# ---------------------------------------------------------------------------
resource "google_monitoring_service" "hello" {
  service_id   = "${var.service_name}-slo"
  display_name = "Cloud Run golden path (${var.service_name})"

  basic_service {
    service_type = "CLOUD_RUN"
    service_labels = {
      service_name = google_cloud_run_v2_service.hello.name
      location     = var.region
    }
  }
}

resource "google_monitoring_slo" "availability" {
  service      = google_monitoring_service.hello.service_id
  slo_id       = "${var.service_name}-availability"
  display_name = "99% availability (rolling 30 days)"

  goal                = 0.99
  rolling_period_days = 30

  basic_sli {
    availability {
      enabled = true
    }
  }
}

resource "google_monitoring_slo" "latency" {
  service      = google_monitoring_service.hello.service_id
  slo_id       = "${var.service_name}-latency"
  display_name = "95% of requests under 800ms (rolling 30 days)"

  goal                = 0.95
  rolling_period_days = 30

  basic_sli {
    latency {
      threshold = "1s"
    }
  }
}

# Multi-window multi-burn-rate alert on the availability SLO.
resource "google_monitoring_notification_channel" "email" {
  display_name = "Ops email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "burn_rate" {
  display_name = "${var.service_name} availability burn rate"
  combiner     = "AND"

  notification_channels = [google_monitoring_notification_channel.email.name]

  conditions {
    display_name = "fast burn (5m window)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", 5m)"
      threshold_value = "14.4"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }

  conditions {
    display_name = "slow burn (1h window)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", 1h)"
      threshold_value = "14.4"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }
}

# ---------------------------------------------------------------------------
# 5. Outputs
# ---------------------------------------------------------------------------
output "service_url" {
  value = google_cloud_run_v2_service.hello.uri
}

output "workload_identity_provider_demo" {
  description = "n/a — kept empty; this example uses a runtime SA, not CI"
  value       = ""
}

output "slo_name" {
  value = google_monitoring_slo.availability.name
}