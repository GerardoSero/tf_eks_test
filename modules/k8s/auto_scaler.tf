resource "kubernetes_service_account" "cluster_autoscaler_account" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      "k8s-addon"                  = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"                    = "cluster-autoscaler"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = var.autoscaler_role_arn
    }
  }
}

resource "kubernetes_cluster_role" "cluster_autoscaler_cluster_role" {
  metadata {
    name = "cluster-autoscaler"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
  }

  rule {
    api_groups = ["*"]
    resources  = ["events", "endpoints"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/eviction"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["update"]
  }

  rule {
    api_groups     = [""]
    resources      = ["endpoints"]
    resource_names = ["cluster-autoscaler"]
    verbs          = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["watch", "list", "get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["watch", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses", "csinodes"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "patch"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = ["coordination.k8s.io"]
    resource_names = ["cluster-autoscaler"]
    resources      = ["leases"]
    verbs          = ["get", "update"]
  }
}

resource "kubernetes_role" "cluster_autoscaler_role" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "list", "watch"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cluster-autoscaler-status", "cluster-autoscaler-priority-expander"]
    verbs          = ["delete", "get", "update", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "cluster_autoscaler_cluster_role_binding" {
  metadata {
    name = "cluster-autoscaler"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cluster_autoscaler_cluster_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cluster_autoscaler_account.metadata[0].name
    namespace = kubernetes_service_account.cluster_autoscaler_account.metadata[0].namespace
  }
}

resource "kubernetes_role_binding" "cluster_autoscaler_role_binding" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.cluster_autoscaler_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cluster_autoscaler_account.metadata[0].name
    namespace = kubernetes_service_account.cluster_autoscaler_account.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      "app" = "cluster-autoscaler"
    }
  }

  spec {
    replicas = "1"

    selector {
      match_labels = {
        "app" = "cluster-autoscaler"
      }
    }

    template {
      metadata {
        labels = {
          "app" = "cluster-autoscaler"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8085"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.cluster_autoscaler_account.metadata[0].name
        container {
          image             = "k8s.gcr.io/autoscaling/cluster-autoscaler:v1.16.7"
          name              = "cluster-autoscaler"
          image_pull_policy = "Always"
          command = [
            "./cluster-autoscaler",
            "--v=4",
            "--stderrthreshold=info",
            "--cloud-provider=aws",
            "--skip-nodes-with-local-storage=false",
            "--expander=least-waste",
            "--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${var.cluster_id}",
            "--balance-similar-node-groups",
            "--skip-nodes-with-system-pods=false"
          ]

          resources {
            limits = {
              "cpu"    = "100m"
              "memory" = "300Mi"
            }
            requests = {
              "cpu"    = "100m"
              "memory" = "300Mi"
            }
          }

          volume_mount {
            name       = "ssl-certs"
            mount_path = "/etc/ssl/certs/ca-certificates.crt" #/etc/ssl/certs/ca-bundle.crt for Amazon Linux Worker Nodes
            read_only  = true
          }
        }

        volume {
          name = "ssl-certs"
          host_path {
            path = "/etc/ssl/certs/ca-bundle.crt"
          }
        }
      }
    }
  }
}

# Overprovisioning

resource "kubernetes_namespace" "overprovisioning_namespace" {
  metadata {
    name = "overprovisioning"
  }
}

resource "kubernetes_priority_class" "overprovisioning_priority_class" {
  metadata {
    name = "overprovisioning"
  }

  value = -1
  global_default = false
  description = "Priority class used by overprovisioning"
}

resource "kubernetes_service_account" "overprovisioning_account" {
  metadata {
    name = "cluster-proportional-autoscaler"
    namespace = kubernetes_namespace.overprovisioning_namespace.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "overprovisioning_cluster_role" {
  metadata {
    name = "cluster-proportional-autoscaler"
  }

  rule {
    api_groups = [""]
    resources = ["nodes"]
    verbs = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources = ["replicationcontrollers/scale"]
    verbs = ["get", "update"]
  }

  rule {
    api_groups = ["extensions","apps"]
    resources = ["deployments/scale", "replicasets/scale"]
    verbs = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources = ["configmaps"]
    verbs = ["get", "create"]
  }
}

resource "kubernetes_cluster_role_binding" "overprovisioning_cluster_role_binding" {
  metadata {
    name = "cluster-proportional-autoscaler"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.overprovisioning_cluster_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.overprovisioning_account.metadata[0].name
    namespace = kubernetes_service_account.overprovisioning_account.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "overprovisioning" {
  metadata {
    name = "overprovisioning"
    namespace = kubernetes_namespace.overprovisioning_namespace.metadata[0].name
  }

  spec {
    replicas = "1"

    selector {
      match_labels = {
        "run" = "overprovisioning"
      }
    }

    template {
      metadata {
        labels = {
          "run" = "overprovisioning"
        }  
      }  

      spec {
        priority_class_name = kubernetes_priority_class.overprovisioning_priority_class.metadata[0].name
        container {
          name = "reserve-resources"
          image = "k8s.gcr.io/pause"
          resources {
            requests = {
              "cpu" = "200m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "overprovisioning_autoscaler" {
  metadata {
    name = "overprovisioning-autoscaler"
    namespace = kubernetes_namespace.overprovisioning_namespace.metadata[0].name
    labels = {
      "app" = "overprovisioning-autoscaler"
    }
  }

  spec {
    replicas = "1"

    selector {
      match_labels = {
        "app" = "overprovisioning-autoscaler"
      }
    }

    template {
      metadata {
        labels = {
          "app" = "overprovisioning-autoscaler"
        }  
      }  

      spec {
        service_account_name = kubernetes_service_account.overprovisioning_account.metadata[0].name
        container {
          name = "autoscaler"
          image = "k8s.gcr.io/cluster-proportional-autoscaler-amd64:1.1.2"
          command = [
            "./cluster-proportional-autoscaler",
            "--namespace=${kubernetes_namespace.overprovisioning_namespace.metadata[0].name}",
            "--configmap=overprovisioning-autoscaler",
            "--default-params={\"linear\":{\"coresPerReplica\":1}}",
            "--target=deployment/overprovisioning",
            "--logtostderr=true",
            "--v=2"
          ]
        }
      }
    }
  }
}