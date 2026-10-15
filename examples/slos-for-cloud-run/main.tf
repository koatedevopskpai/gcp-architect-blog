# Companion example: SLOs for Cloud Run (Blog 4, tier-1 live run).
#
# Creates a fault-injecting Cloud Run service, availability + latency SLOs on a
# monitored service, and three-tier multi-window multi-burn-rate alerting
# (fast / medium / slow), plus a dashboard.
#
# Deploy in two phases (Artifact Registry must exist before you can push the
# image it serves):
#
#   terraform apply -target="google_artifact_registry_repository.images" \
#     -var="project_id=gcp-architect-demo-2026"
#   gcloud builds submit --tag <image>
#   terraform apply -var="project_id=gcp-architect-demo-2026"
#
# See README.md for the full runbook and the screenshot capture sequence.

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

variable "artifact_repo" {
  type    = string
  default = "slo-images"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "image" {
  description = "Fault-injecting demo image. Defaults to <region>-docker.pkg.dev/<project>/<artifact_repo>/slo-demo:<image_tag>."
  type        = string
  default     = ""
}

variable "service_name" {
  type    = string
  default = "slo-demo"
}

variable "page_email" {
  description = "Email that receives page-tier (fast/medium burn) alerts."
  type        = string
  default     = "ops@example.com"
}

variable "ticket_email" {
  description = "Email that receives ticket-tier (slow burn) alerts."
  type        = string
  default     = "ops@example.com"
}

variable "baseline_fail_rate" {
  description = "Baseline random failure rate (0-1) baked into the service."
  type        = number
  default     = 0.0
}

locals {
  image = var.image != "" ? var.image : "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo}/slo-demo:${var.image_tag}"
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Attribute API quota/usage to the target project instead of whatever the
  # machine's ADC quota project happens to be. Without this, a user-ADC
  # mismatch ("project ... does not match quota project ...") breaks resources
  # such as Billing Budgets. Set the ADC quota project globally with:
  #   gcloud auth application-default set-quota-project <project>
  user_project_override = true
  billing_project       = var.project_id

  default_labels = {
    project     = var.project_id
    environment = "demo"
    managed_by  = "terraform"
    workload    = "blog4-slos-for-cloud-run"
    cost_center = "cc-gcp-platform"
  }
}

data "google_project" "current" {}

# ---------------------------------------------------------------------------
# 0. Enable the APIs this example needs
# ---------------------------------------------------------------------------
locals {
  services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "cloudbuild.googleapis.com", # for `gcloud builds submit`
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.services)

  project = var.project_id
  service = each.value

  # Keep APIs enabled on destroy — other workloads (and the project itself)
  # may rely on them.
  disable_dependent_services = false
  disable_on_destroy         = false
}

# ---------------------------------------------------------------------------
# 1. Artifact Registry + runtime identity
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = var.artifact_repo
  description   = "Fault-injecting demo image for the SLO post"
  format        = "DOCKER"

  labels = {
    finops_owner = "platform"
    env          = "demo"
  }

  depends_on = [google_project_service.services]
}

resource "google_service_account" "run" {
  account_id   = "slo-demo-sa"
  display_name = "SLO demo Cloud Run runtime"
  description  = "Runtime identity for the SLO demo service"

  depends_on = [google_project_service.services]
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.images.id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.run.email}"
}

# ---------------------------------------------------------------------------
# 2. The service (golden-path defaults; /work provides the fault levers)
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "svc" {
  name                = var.service_name
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.run.email

    containers {
      image = local.image
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
      env {
        name  = "FAIL_RATE"
        value = tostring(var.baseline_fail_rate)
      }
      startup_probe {
        tcp_socket { port = 8080 }
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

  depends_on = [
    google_artifact_registry_repository.images,
    google_artifact_registry_repository_iam_member.reader,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.svc.location
  name     = google_cloud_run_v2_service.svc.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------
# 3. Monitored service + SLOs (the contract with the error budget)
# ---------------------------------------------------------------------------
resource "google_monitoring_service" "svc" {
  service_id   = "${var.service_name}-svc"
  display_name = "SLO demo (${var.service_name})"

  basic_service {
    service_type = "CLOUD_RUN"
    service_labels = {
      service_name = google_cloud_run_v2_service.svc.name
      location     = var.region
    }
  }

  depends_on = [
    google_project_service.services,
    google_cloud_run_v2_service.svc,
  ]
}

resource "google_monitoring_slo" "availability" {
  service      = google_monitoring_service.svc.service_id
  slo_id       = "${var.service_name}-availability"
  display_name = "99.9% availability (rolling 30 days)"

  goal                = 0.999
  rolling_period_days = 30

  basic_sli {
    availability {
      enabled = true
    }
  }
}

resource "google_monitoring_slo" "latency" {
  service      = google_monitoring_service.svc.service_id
  slo_id       = "${var.service_name}-latency"
  display_name = "99% of requests under 1s (rolling 30 days)"

  goal                = 0.99
  rolling_period_days = 30

  basic_sli {
    latency {
      # Protobuf duration: whole seconds only. "800ms"/"500ms" are rejected by
      # the API — see the post's gotchas.
      threshold = "1s"
    }
  }
}

# ---------------------------------------------------------------------------
# 4. Notification channels — page vs ticket tiers
# ---------------------------------------------------------------------------
resource "google_monitoring_notification_channel" "page" {
  display_name = "SLO page (fast/medium burn)"
  type         = "email"
  labels = {
    email_address = var.page_email
  }
}

resource "google_monitoring_notification_channel" "ticket" {
  display_name = "SLO ticket (slow burn)"
  type         = "email"
  labels = {
    email_address = var.ticket_email
  }
}

# ---------------------------------------------------------------------------
# 5. Multi-window multi-burn-rate alerting (Google SRE workbook table)
#    Each policy ANDs a short window with a long window so a brief blip on one
#    window can't page on its own. Thresholds assume a 30-day window.
# ---------------------------------------------------------------------------
locals {
  slo = google_monitoring_slo.availability.name
}

# Fast burn: 14.4x over 5m AND 1h -> page (budget gone in ~50h).
resource "google_monitoring_alert_policy" "fast_burn" {
  display_name          = "${var.service_name} availability — fast burn (14.4x)"
  combiner              = "AND"
  notification_channels = [google_monitoring_notification_channel.page.name]

  conditions {
    display_name = "14.4x over 5m"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${local.slo}\", \"5m\")"
      threshold_value = "14.4"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }

  conditions {
    display_name = "14.4x over 1h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${local.slo}\", \"1h\")"
      threshold_value = "14.4"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }
}

# Medium burn: 6x over 30m AND 6h -> page (budget gone in ~5d).
resource "google_monitoring_alert_policy" "medium_burn" {
  display_name          = "${var.service_name} availability — medium burn (6x)"
  combiner              = "AND"
  notification_channels = [google_monitoring_notification_channel.page.name]

  conditions {
    display_name = "6x over 30m"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${local.slo}\", \"30m\")"
      threshold_value = "6"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }

  conditions {
    display_name = "6x over 6h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${local.slo}\", \"6h\")"
      threshold_value = "6"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }
}

# Slow burn: 1x over 6h AND 24h -> ticket (budget gone in ~30d).
resource "google_monitoring_alert_policy" "slow_burn" {
  display_name          = "${var.service_name} availability — slow burn (1x)"
  combiner              = "AND"
  notification_channels = [google_monitoring_notification_channel.ticket.name]

  conditions {
    display_name = "1x over 6h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${local.slo}\", \"6h\")"
      threshold_value = "1"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }

  conditions {
    display_name = "1x over 24h"
    condition_threshold {
      # `select_slo_burn_rate` caps its lookback at 24h — the textbook 3d window
      # is not expressible, so 24h is the longest slow-burn window available.
      filter          = "select_slo_burn_rate(\"${local.slo}\", \"24h\")"
      threshold_value = "1"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }
}

# ---------------------------------------------------------------------------
# 6. Dashboard — request rate, latency, error rate, instance count
#    (SLO burn lives on the Monitoring → SLOs page; captured as a screenshot)
# ---------------------------------------------------------------------------
resource "google_monitoring_dashboard" "svc" {
  dashboard_json = jsonencode({
    displayName = "SLO demo (${var.service_name})"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Request rate (req/s)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${var.service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = []
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Error rate (5xx req/s)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${var.service_name}\" metric.label.\"response_code_class\"=\"5xx\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = []
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 0
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Request latency (p50 / p95 / p99)"
            xyChart = {
              dataSets = [
                {
                  legendTemplate = "p50"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${var.service_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_PERCENTILE_50"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = []
                      }
                    }
                  }
                },
                {
                  legendTemplate = "p95"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${var.service_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_PERCENTILE_95"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = []
                      }
                    }
                  }
                },
                {
                  legendTemplate = "p99"
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${var.service_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_PERCENTILE_99"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = []
                      }
                    }
                  }
                },
              ]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Instance count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/container/instance_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${var.service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = []
                    }
                  }
                }
              }]
            }
          }
        },
      ]
    }
  })
}
