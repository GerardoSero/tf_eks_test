resource "kubernetes_deployment" "hpa" {
  metadata {
    name = "hpa"
    labels = {
      "app" = "hpa"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "hpa"
      }
    }
    template {
      metadata {
        labels = {
          app = "hpa"
        }
      }
      spec {
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["hpa"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }
        container {
          image = "k8s.gcr.io/hpa-example"
          name  = "hpa"

          port {
            container_port = 80
          }

          resources {
            limits = {
              memory = "512M"
              cpu    = "400m"
            }
            requests = {
              memory = "128M"
              cpu    = "300m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "hpa_hpa" {
  metadata {
    name = "hpa"
    labels = {
      "app" = "hpa"
    }
  }

  spec {
    scale_target_ref {
      kind        = "Deployment"
      name        = "hpa"
      api_version = "apps/v1"
    }

    min_replicas = 1
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

resource "kubernetes_service" "hpa" {
  metadata {
    name = "hpa"
    labels = {
      "app" = "hpa"
    }
  }
  spec {
    type = "ClusterIP"
    selector = {
      app = kubernetes_deployment.hpa.spec.0.template.0.metadata.0.labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_ingress" "hpa_ingress" {
  metadata {
    name = "hpa"
    annotations = {
      "kubernetes.io/ingress.class" = "kong"
      "konghq.com/strip-path"       = "true"
    }
  }

  spec {
    rule {
      http {
        path {
          path = "/hpa"
          backend {
            service_name = "hpa"
            service_port = "80"
          }
        }
      }
    }
  }
}

