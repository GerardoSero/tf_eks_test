terraform {
  required_version = ">=0.12.0"

  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.22.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.1.0"
    }
  }
}

provider "aws" {
  profile = var.profile
  region  = var.aws_region
}

provider "tls" {
}

provider "kubernetes" {
  host                   = module.eks.cluster.endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["--profile", var.profile, "--region", var.aws_region, "eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster.endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["--profile", var.profile, "--region", var.aws_region, "eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}