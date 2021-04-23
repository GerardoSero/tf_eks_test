# resource "helm_release" "echo_app" {
#   name       = "echo"
#   wait       = false
#   chart      = "./charts/webapp"
#   namespace  = "default"

#   values = [file("./helm_values/echo_app.yaml")]
# }

resource "kubernetes_deployment" "echo" {
  metadata {
    name = "echo"
    labels = {
      "app" = "echo"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "echo"
      }
    }
    template {
      metadata {
        labels = {
          app = "echo"
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
                    values   = ["echo"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }
        container {
          image = "gcr.io/kubernetes-e2e-test-images/echoserver:2.2"
          name  = "echo"

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          port {
            container_port = 8080
          }

          resources {
            limits = {
              memory = "128M"
              cpu    = "200m"
            }
            requests = {
              memory = "128M"
              cpu    = "150m"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].replicas
    ]
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "echo_hpa" {
  metadata {
    name = "echo"
    labels = {
      "app" = "echo"
    }
  }

  spec {
    scale_target_ref {
      kind        = "Deployment"
      name        = "echo"
      api_version = "apps/v1"
    }

    min_replicas = 1
    max_replicas = 10

    metric {
      type = "Pods"
      pods {
        metric {
          name = "my_record"
        }
        target {
          type          = "AverageValue"
          average_value = "900m"
        }
      }
    }

    # metric {
    #   type = "Resource"
    #   resource {
    #     name = "cpu"
    #     target {
    #       type                = "Utilization"
    #       average_utilization = 70
    #     }
    #   }
    # }
  }
}

resource "kubernetes_service" "echo" {
  metadata {
    name = "echo"
    labels = {
      "app" = "echo"
    }
  }
  spec {
    type = "ClusterIP"
    selector = {
      app = kubernetes_deployment.echo.spec.0.template.0.metadata.0.labels.app
    }
    port {
      port        = 80
      target_port = 8080
    }
  }
}

resource "kubernetes_ingress" "echo_ingress" {
  count = var.ingress_type == "kong" ? 1 : 0

  metadata {
    name = "echo-kong"
    annotations = {
      "kubernetes.io/ingress.class" = "kong"
      "konghq.com/override"         = "sample-customization"
    }
  }

  spec {
    rule {
      http {
        path {
          path = "/echo"
          backend {
            service_name = "echo"
            service_port = "80"
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress" "echo_ingress_nginx" {
  count = var.ingress_type == "nginx" ? 1 : 0

  metadata {
    name = "echo-nginx"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      http {
        path {
          path = "/echo"
          backend {
            service_name = "echo"
            service_port = "80"
          }
        }
      }
    }
  }
}
