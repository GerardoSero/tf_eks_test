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
