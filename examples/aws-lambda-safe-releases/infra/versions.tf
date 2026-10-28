terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state is intentional for this reproducible example.
  # In a client environment, use an S3 backend with locking and a dedicated key.
}
