terraform {
  required_version = ">=0.12.0"
  # backend "s3" {
  #   region  = "us-east-1"
  #   profile = "default"
  #   key     = "terraform_state_file"
  #   bucket  = "terraformstatebucket995551235"
  # }

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

module "eks" {
  source       = "./modules/eks"
  cluster_name = var.cluster_name
}

module "k8s" {
  source              = "./modules/k8s"
  cluster_id          = module.eks.cluster.id # creates dependency on cluster creation
  autoscaler_role_arn = module.eks.autoscaler_role_arn
}
