terraform {
  required_providers {
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

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress"
  }
}

resource "helm_release" "kong_ingress" {
  name       = "kong-ingress"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  namespace  = kubernetes_namespace.ingress.metadata.0.name

  set {
    name  = "ingressController.installCRDs"
    value = "false"
  }

  values = [file("./helm_values/kong.yaml")]
}
