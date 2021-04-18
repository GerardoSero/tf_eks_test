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

resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata.0.name

  values = [file("./helm_values/prometheus_stack.yaml")]
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
