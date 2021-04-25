resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress"
  }
}

resource "helm_release" "kong_ingress" {
  count = var.ingress_type == "kong" ? 1 : 0

  name       = "kong-ingress"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  namespace  = kubernetes_namespace.ingress.metadata.0.name

  set {
    name  = "ingressController.installCRDs"
    value = "false"
  }

  values = [file("./helm_values/kong_ingress.yaml")]
}

resource "helm_release" "nginx_ingress" {
  count = var.ingress_type == "nginx" ? 1 : 0

  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress.metadata.0.name

  values = [file("./helm_values/nginx_ingress.yaml")]
}
