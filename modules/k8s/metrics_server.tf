# Based on https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.4.2/components.yaml

resource "kubernetes_service_account" "metrics_server_accout" {
  metadata {
    labels = {
      "k8s-app" = "metrics-server"
    }

    name = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role" "metrics_server_reader_cluster_role" {
  metadata {
    labels = {
      "k8s-app" = "metrics-server"
      "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
      "rbac.authorization.k8s.io/aggregate-to-edit" = "true"
      "rbac.authorization.k8s.io/aggregate-to-view" = "true"
    }
    name = "system:aggregated-metrics-reader"
  }

  rule {
    api_groups = [ "metrics.k8s.io" ]
    resources = [ "pods", "nodes" ]
    verbs = [ "get", "list", "watch" ]
  }
}

resource "kubernetes_cluster_role" "metrics_server_cluster_role" {
  metadata {
    labels = {
      k8s-app = "metrics-server"
    }
    name = "system:metrics-server"
  }

  rule {
    api_groups = [ "" ]
    resources = [ "pods", "nodes", "nodes/stats", "namespaces", "configmaps" ]
    verbs = [ "get", "list", "watch" ]
  }
}

resource "kubernetes_role_binding" "metrics_server_reader_role_binding" {
  metadata {
    labels = {
      k8s-app = "metrics-server"
    }
    name = "metrics-server-auth-reader"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "extension-apiserver-authentication-reader"
  }

  subject {
    kind = "ServiceAccount"
    name = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "metrics_server_auth_cluster_role_binding" {
  metadata {
    labels = {
      k8s-app = "metrics-server"
    }
    name = "metrics-server:system:auth-delegator"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "system:auth-delegator"
  }

  subject {
    kind = "ServiceAccount"
    name = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "metrics_server_cluster_role_binding" {
  metadata {
    labels = {
      k8s-app = "metrics-server"
    }
    name = "system:metrics-server"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "system:metrics-server"
  }

  subject {
    kind = "ServiceAccount"
    name = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_service" "metrics_server_service" {
  metadata {
    labels = {
      k8s-app = "metrics-server"
    }
    name = "metrics-server"
    namespace = "kube-system"
  }
  
  spec {
    port {
      name = "https"
      port = 443
      protocol = "TCP"
      target_port = "https"
    }

    selector = {
      k8s-app = "metrics-server"
    }
  }
}

resource "kubernetes_deployment" "metrics_server_deployment" {
  metadata {
    labels = {
      k8s-app = "metrics-server"
    }
    name = "metrics-server"
    namespace = "kube-system"
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "metrics-server"
      }
    }

    strategy {
      rolling_update {
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = "metrics-server"
        }
      }

      spec {
        container {
          args = [
            "--cert-dir=/tmp",
            "--secure-port=4443",
            "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
            "--kubelet-use-node-status-port"
          ]

          image = "k8s.gcr.io/metrics-server/metrics-server:v0.4.2"
          image_pull_policy = "IfNotPresent"

          liveness_probe {
            failure_threshold = 3
            http_get {
              path = "/livez"
              port = "https"
              scheme = "HTTPS"
            }
            period_seconds = 10
          }

          name = "metrics-server"

          port {
            container_port = 4443
            name = "https"
            protocol = "TCP"
          }

          readiness_probe {
            failure_threshold = 3
            http_get {
              path = "/readyz"
              port = "https"
              scheme = "HTTPS"
            }
            period_seconds = 10
          }

          security_context {
            read_only_root_filesystem = true
            run_as_non_root = true
            run_as_user = "1000"
          }

          volume_mount {
            mount_path = "/tmp"
            name = "tmp-dir"
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        priority_class_name = "system-cluster-critical"
        service_account_name = "metrics-server"

        volume {
          empty_dir {
            
          }
          name = "tmp-dir"
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.metrics_server_accout,
    kubernetes_cluster_role.metrics_server_reader_cluster_role,
    kubernetes_cluster_role.metrics_server_cluster_role,
    kubernetes_role_binding.metrics_server_reader_role_binding,
    kubernetes_cluster_role_binding.metrics_server_auth_cluster_role_binding,
    kubernetes_cluster_role_binding.metrics_server_cluster_role_binding
  ]
}

resource "kubernetes_api_service" "metrics_server_api_service" {
  metadata {
    labels = {
      k8s-app = "metrics-server"
    }
    name = "v1beta1.metrics.k8s.io"
  } 

  spec {
    group = "metrics.k8s.io"
    group_priority_minimum = 100
    insecure_skip_tls_verify = true

    service {
      name = kubernetes_service.metrics_server_service.metadata[0].name
      namespace = kubernetes_service.metrics_server_service.metadata[0].namespace
    }

    version = "v1beta1"
    version_priority = 100
  }
}

