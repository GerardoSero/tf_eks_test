resource "kubernetes_namespace" "cloudwatch_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service_account" "cloudwatch_service_account" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.cloudwatch_namespace.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_cloudwatch_aim_role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cloudwatch_aim_role_policy_attach
  ]
}

resource "kubernetes_cluster_role" "cloudwatch_cluster_role" {
  metadata {
    name = kubernetes_service_account.cloudwatch_service_account.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "endpoints"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/proxy"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/stats", "configmaps", "events"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cwagent-clusterleader"]
    verbs          = ["get", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "cloudwatch_cluster_role_binding" {
  metadata {
    name = kubernetes_service_account.cloudwatch_service_account.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cloudwatch_service_account.metadata[0].name
    namespace = kubernetes_namespace.cloudwatch_namespace.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cloudwatch_cluster_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

# Based on https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-metrics.html
resource "kubernetes_config_map" "cloudwatch_configmap" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.cloudwatch_namespace.metadata[0].name
  }

  data = {
    "cwagentconfig.json" = jsonencode({
      "logs" : {
        "metrics_collected" : {
          "kubernetes" : {
            "cluster_name" : "${var.cluster_name}",
            "metrics_collection_interval" : 15
          }
        },
        "force_flush_interval" : 5
      },
      "metrics" : {
        "metrics_collected" : {
          "statsd" : {
            "service_address" : ":8125"
          }
        }
      }
    })
  }
}

# Based on https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml
resource "kubernetes_daemonset" "cloudwatch_demonset" {
  metadata {
    name      = "${var.service_account_name}-agent"
    namespace = kubernetes_namespace.cloudwatch_namespace.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        "name" = "${var.service_account_name}-agent"
      }
    }

    template {
      metadata {
        labels = {
          "name" = "${var.service_account_name}-agent"
        }
      }

      spec {
        container {
          name  = "${var.service_account_name}-agent"
          image = "amazon/cloudwatch-agent:1.247347.5b250583"

          port {
            container_port = 8125
            host_port      = 8125
            protocol       = "UDP"
          }

          resources {
            limits = {
              "cpu"    = "200m"
              "memory" = "200Mi"
            }
            requests = {
              "cpu"    = "200m"
              "memory" = "200Mi"
            }
          }

          # Please don't change below envs
          env {
            name = "HOST_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "K8S_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.5"
          }

          # Please don't change the mountPath
          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            mount_path = "/rootfs"
            read_only  = true
          }

          volume_mount {
            name       = "dockersock"
            mount_path = "/var/run/docker.sock"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdocker"
            mount_path = "/var/lib/docker"
            read_only  = true
          }

          volume_mount {
            name       = "sys"
            mount_path = "/sys"
            read_only  = true
          }

          volume_mount {
            name       = "devdisk"
            mount_path = "/dev/disk"
            read_only  = true
          }
        }

        volume {
          name = "cwagentconfig"
          config_map {
            name = kubernetes_config_map.cloudwatch_configmap.metadata[0].name
          }
        }

        volume {
          name = "rootfs"
          host_path {
            path = "/"
          }
        }

        volume {
          name = "dockersock"
          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "varlibdocker"
          host_path {
            path = "/var/lib/docker"
          }
        }

        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"
          host_path {
            path = "/dev/disk/"
          }
        }

        termination_grace_period_seconds = 60
        service_account_name             = kubernetes_service_account.cloudwatch_service_account.metadata[0].name
      }
    }
  }
}
