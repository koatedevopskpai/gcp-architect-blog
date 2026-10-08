resource "google_project" "demo" {
  name                = var.project_name
  project_id          = var.project_id
  org_id              = var.org_id
  billing_account     = var.billing_account_id
  auto_create_network = false

  labels = {
    project     = var.project_id
    environment = "demo"
    managed_by  = "terraform"
    workload    = "gcp-architect-demo"
    cost_center = var.cost_center
  }
}

locals {
  services = [
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    # cloudrun.googleapis.com is enabled via gcloud (a Service Usage propagation
    # quirk on this project made the provider's enable call fail; imported state
    # documented in docs/blog-2-cloud-run-golden-path.md):
    #   gcloud services enable run.googleapis.com --project=gcp-architect-demo-2026
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudbuild.googleapis.com",
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.services)

  project = google_project.demo.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}