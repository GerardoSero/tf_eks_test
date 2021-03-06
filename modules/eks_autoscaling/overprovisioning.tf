# Overprovisioning

resource "kubernetes_priority_class" "overprovisioning_priority_class" {
  count = var.overprovisioning != "disabled" ? 1 : 0

  metadata {
    name = "overprovisioning"
  }

  value          = -1
  global_default = false
  description    = "Priority class used by overprovisioning"
}

resource "kubernetes_service_account" "overprovisioning_account" {
  count = var.overprovisioning != "disabled" ? 1 : 0

  metadata {
    name      = "cluster-proportional-autoscaler"
    namespace = kubernetes_namespace.autoscaling_namespace.metadata[0].name
  }

  lifecycle {
    ignore_changes = [secret]
  }
}

resource "kubernetes_cluster_role" "overprovisioning_cluster_role" {
  count = var.overprovisioning != "disabled" ? 1 : 0

  metadata {
    name = "cluster-proportional-autoscaler"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["replicationcontrollers/scale"]
    verbs      = ["get", "update"]
  }

  rule {
    api_groups = ["extensions", "apps"]
    resources  = ["deployments/scale", "replicasets/scale"]
    verbs      = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "create"]
  }
}

resource "kubernetes_cluster_role_binding" "overprovisioning_cluster_role_binding" {
  count = var.overprovisioning != "disabled" ? 1 : 0

  metadata {
    name = "cluster-proportional-autoscaler"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.overprovisioning_cluster_role[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.overprovisioning_account[0].metadata[0].name
    namespace = kubernetes_service_account.overprovisioning_account[0].metadata[0].namespace
  }
}

resource "kubernetes_deployment" "overprovisioning" {
  count = var.overprovisioning != "disabled" ? 1 : 0

  metadata {
    name      = "overprovisioning"
    namespace = kubernetes_namespace.autoscaling_namespace.metadata[0].name
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
        priority_class_name = kubernetes_priority_class.overprovisioning_priority_class[0].metadata[0].name
        container {
          name  = "reserve-resources"
          image = "k8s.gcr.io/pause"
          resources {
            requests = {
              "cpu"    = var.overprovisioning_resource_request.cpu
              "memory" = var.overprovisioning_resource_request.memory
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

resource "kubernetes_config_map" "overprovisioning_config" {
  count = var.overprovisioning != "disabled" ? 1 : 0

  metadata {
    name      = "overprovisioning-autoscaler"
    namespace = kubernetes_namespace.autoscaling_namespace.metadata[0].name
  }

  # replicas = max( ceil( cores * 1/coresPerReplica ) , ceil( nodes * 1/nodesPerReplica ) )
  data = {
    "linear" = jsonencode({
      "coresPerReplica" : 1,
      "nodesPerReplica" : 1,
      "min" : 1,
      "max" : 100,
      "preventSinglePointFailure" : true,
      "includeUnschedulableNodes" : true
    })
  }
}

resource "kubernetes_deployment" "overprovisioning_autoscaler" {
  count = var.overprovisioning != "disabled" ? 1 : 0

  metadata {
    name      = "overprovisioning-autoscaler"
    namespace = kubernetes_namespace.autoscaling_namespace.metadata[0].name
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
        service_account_name = kubernetes_service_account.overprovisioning_account[0].metadata[0].name
        container {
          name  = "autoscaler"
          image = "k8s.gcr.io/cluster-proportional-autoscaler-amd64:1.6.0"
          command = [
            "./cluster-proportional-autoscaler",
            "--namespace=${kubernetes_namespace.autoscaling_namespace.metadata[0].name}",
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