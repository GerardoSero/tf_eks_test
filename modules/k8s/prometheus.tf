resource "kubernetes_namespace" "prometheus" {
  count = var.prometheus_enabled ? 1 : 0

  metadata {
    name = "prometheus"
  }
}
resource "helm_release" "prometheus" {
  count = var.prometheus_enabled ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.prometheus[0].metadata.0.name

  values = [file("./helm_values/prometheus_stack.yaml")]

  set {
    name  = "grafana.ingress.enabled"
    value = var.ingress_type != "none"
  }

  set {
    name  = "grafana.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = var.ingress_type
  }

  set {
    name  = "grafana.ingress.hosts[0]"
    value = var.grafana_host
  }
}

resource "helm_release" "prometheus_adapter" {
  count = var.prometheus_enabled ? 1 : 0

  name       = "prometheus-adapter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-adapter"
  namespace  = kubernetes_namespace.prometheus[0].metadata.0.name

  values = [file("./helm_values/prometheus_adapter.yaml")]
}


# resource "kubernetes_ingress" "grafana_ingress" {
#   metadata {
#     name = "grafana"
#     annotations = {
#       "kubernetes.io/ingress.class" = "kong"
#       "konghq.com/strip-path"       = "true"
#     }
#   }

#   spec {
#     rule {
#       http {
#         path {
#           path = "/grafana"
#           backend {
#             service_name = "prometheus-grafana"
#             service_port = "80"
#           }
#         }
#       }
#     }
#   }
# }

