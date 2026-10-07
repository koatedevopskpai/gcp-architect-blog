resource "google_project" "blog" {
  name                = var.project_name
  project_id          = var.project_id
  org_id              = var.org_id
  billing_account     = var.billing_account_id
  auto_create_network = false

  labels = {
    project     = var.project_id
    environment = "prod"
    managed_by  = "terraform"
    workload    = "gcp-architect-blog"
    cost_center = var.cost_center
  }
}

locals {
  services = [
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.services)

  project = google_project.blog.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}
