terraform {
  required_version = ">=0.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.22.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }
  }
}
