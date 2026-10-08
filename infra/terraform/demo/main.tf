terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "gcp-proof-platform-tfstate"
    prefix = "blog-demo"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    project             = var.project_id
    environment         = "demo"
    managed_by          = "terraform"
    cost_center         = var.cost_center
    business_unit       = var.business_unit
    owner               = var.tag_owner
    workload            = "gcp-architect-demo"
    cost_category       = "engineering-rnd"
    data_classification = "public-reference"
  }
}