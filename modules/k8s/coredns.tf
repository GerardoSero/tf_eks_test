###
# Also need to add the safe-to-evict annotation due to the use of the emptyDir volume
# kubectl n kube-system patch deployment/coredns --dry-run=true -o yaml -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict":"true"}}}}}'
###

resource "kubernetes_pod_disruption_budget" "coredns_pdb" {
  metadata {
    labels = {
      k8s-app = "coredns"
    }
    name      = "coredns"
    namespace = "kube-system"
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "kube-dns"
      }
    }

    max_unavailable = "1"
  }
}
