resource "kubernetes_service_account" "externaldns_service_account" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name      = var.service_account_name
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_externaldns_aim_role[0].arn
    }
  }

}

resource "kubernetes_cluster_role" "externaldns_cluster_role" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name = "${var.service_account_name}-role"
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "externaldns_cluster_role_binding" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name = "${var.service_account_name}-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.externaldns_cluster_role[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.externaldns_service_account[0].metadata[0].name
    namespace = kubernetes_service_account.externaldns_service_account[0].metadata[0].namespace
  }
}

resource "kubernetes_deployment" "externaldns" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name      = "external-dns"
    namespace = "kube-system"
  }

  spec {
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app" = "external-dns"
      }
    }

    template {
      metadata {
        labels = {
          "app" = "external-dns"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.externaldns_service_account[0].metadata[0].name

        container {
          name  = "external-dns"
          image = "k8s.gcr.io/external-dns/external-dns:v0.7.6"
          args = [
            "--source=service",
            "--source=ingress",
            "--domain-filter=${var.external_dns.public_domain}", # will make ExternalDNS see only the hosted zones matching provided domain, omit to process all available hosted zones
            "--provider=aws",
            "--policy=upsert-only",   # would prevent ExternalDNS from deleting any records, omit to enable full synchronization
            "--aws-zone-type=public", # only look at public hosted zones (valid values are public, private or no value for both)
            "--registry=txt",
            "--txt-owner-id=my-hostedzone-identifier"
          ]
        }

        security_context {
          fs_group = "65534" # For ExternalDNS to be able to read Kubernetes and AWS token files
        }
      }
    }
  }
}
