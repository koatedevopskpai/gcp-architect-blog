terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }

  # Reuses the existing platform state bucket (different prefix) to avoid a
  # bootstrap project. Swap to a dedicated bucket if you prefer isolation.
  backend "gcs" {
    bucket = "gcp-proof-platform-tfstate"
    prefix = "blog-hosting"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    project             = var.project_id
    environment         = "prod"
    managed_by          = "terraform"
    cost_center         = var.cost_center
    business_unit       = var.business_unit
    owner               = var.tag_owner
    workload            = "gcp-architect-blog"
    cost_category       = "marketing"
    data_classification = "public-reference"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
