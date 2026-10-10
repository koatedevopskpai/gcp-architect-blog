terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "project_id" {
  type    = string
  default = "gcp-architect-demo-2026"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "image" {
  type    = string
  default = "us-central1-docker.pkg.dev/gcp-architect-demo-2026/rag/rag-api:latest"
}

variable "alert_email" {
  type    = string
  default = "ops@example.com"
}

provider "google" {
  project = var.project_id
  region  = var.region
  default_labels = {
    project     = var.project_id
    environment = "demo"
    managed_by  = "terraform"
    workload    = "prod-rag-gcp"
    cost_center = "cc-gcp-platform"
  }
}

# --- APIs ---
locals {
  services = [
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "aiplatform.googleapis.com",
  ]
}
resource "google_project_service" "svc" {
  for_each                   = toset(local.services)
  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# --- Artifact Registry for the image ---
resource "google_artifact_registry_repository" "rag" {
  location      = var.region
  repository_id = "rag"
  format        = "DOCKER"
}

# --- Cloud SQL Postgres 15 + pgvector (db-f1-micro = cheapest tier) ---
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "google_sql_database_instance" "pg" {
  name = "rag-pg"
  # PG15 keeps shared-core db-f1-micro available; 16+ drops shared-core tiers,
  # forcing dedicated vCPU (db-custom-*) at a much higher floor.
  database_version = "POSTGRES_15"
  region           = var.region

  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    disk_size         = 10
    disk_type         = "PD_SSD"
    availability_type = "ZONAL"
    disk_autoresize   = false

    ip_configuration {
      ipv4_enabled = true # Cloud Run connects via the Cloud SQL connector (IAM), no authorized networks needed
    }

    backup_configuration {
      enabled = false # demo only
    }
  }
}

resource "google_sql_database" "rag" {
  name     = "rag"
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "rag" {
  name     = "rag"
  instance = google_sql_database_instance.pg.name
  password = random_password.db.result
}

# --- Secret Manager for the DB password ---
resource "google_secret_manager_secret" "db_password" {
  secret_id = "rag-db-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

# --- Runtime identity ---
resource "google_service_account" "rag" {
  account_id   = "rag-runtime"
  display_name = "RAG API runtime"
}

resource "google_project_iam_member" "rag_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.rag.email}"
}

resource "google_project_iam_member" "rag_secret" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.rag.email}"
}

resource "google_project_iam_member" "rag_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.rag.email}"
}

resource "google_artifact_registry_repository_iam_member" "rag_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.rag.id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.rag.email}"
}

# --- Cloud Run service ---
resource "google_cloud_run_v2_service" "rag" {
  name                = "rag-api"
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.rag.email

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.pg.connection_name]
      }
    }

    containers {
      image = var.image
      resources {
        limits = { cpu = "1", memory = "512Mi" }
      }
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
      env {
        name  = "VECTOR_BACKEND"
        value = "pgvector"
      }
      env {
        name  = "EMBEDDING_PROVIDER"
        value = "vertex"
      }
      env {
        name  = "VERTEX_EMBED_MODEL"
        value = "text-embedding-004"
      }
      env {
        name  = "VERTEX_EMBED_DIM"
        value = "256"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "VERTEX_LOCATION"
        value = var.region
      }
      env {
        name  = "CLOUD_SQL_CONNECTION_NAME"
        value = google_sql_database_instance.pg.connection_name
      }
      env {
        name  = "DB_NAME"
        value = google_sql_database.rag.name
      }
      env {
        name  = "DB_USER"
        value = google_sql_user.rag.name
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
    timeout = "30s"
    annotations = {
      "run.googleapis.com/startup-cpu-boost"     = "true"
      "run.googleapis.com/execution-environment" = "gen2"
    }
  }

  # Explicit ordering so `terraform destroy` tears the service down before the
  # database it mounts — no state surgery needed.
  depends_on = [google_project_service.svc, google_sql_database_instance.pg]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.rag.location
  name     = google_cloud_run_v2_service.rag.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# --- SLO: availability + burn alert (the blog pattern) ---
resource "google_monitoring_service" "rag" {
  service_id   = "rag-api-slo"
  display_name = "RAG API"
  basic_service {
    service_type = "CLOUD_RUN"
    service_labels = {
      service_name = google_cloud_run_v2_service.rag.name
      location     = var.region
    }
  }
}

resource "google_monitoring_slo" "availability" {
  service             = google_monitoring_service.rag.service_id
  slo_id              = "rag-availability"
  goal                = 0.99
  rolling_period_days = 30
  basic_sli {
    availability { enabled = true }
  }
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Ops email"
  type         = "email"
  labels       = { email_address = var.alert_email }
}

resource "google_monitoring_alert_policy" "burn" {
  display_name          = "rag-api availability burn rate"
  combiner              = "AND"
  notification_channels = [google_monitoring_notification_channel.email.name]
  conditions {
    display_name = "burn (1h)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", 1h)"
      threshold_value = "14.4"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }
}

output "service_url" {
  value = google_cloud_run_v2_service.rag.uri
}

output "cloud_sql_connection_name" {
  value = google_sql_database_instance.pg.connection_name
}
