terraform {
  required_version = ">=0.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.22.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.1.0"
    }
  }
}

resource "aws_iam_policy" "eks_node_autoscaling_policy" {
  name        = "${var.cluster_name}-node-autoscaling"
  path        = "/"
  description = "Node AutoScaling Policy for ${var.cluster_name}"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      }
    ]
  })
}

data "aws_iam_policy_document" "eks_node_asume_role_with_oidc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_accout_name}"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_node_autoscaling_aim_role" {
  name               = "${var.cluster_name}-node-autoscaling"
  assume_role_policy = data.aws_iam_policy_document.eks_node_asume_role_with_oidc.json
}

resource "aws_iam_role_policy_attachment" "eks_node_autoscaling_aim_role_policy_attach" {
  role       = aws_iam_role.eks_node_autoscaling_aim_role.name
  policy_arn = aws_iam_policy.eks_node_autoscaling_policy.arn
}

resource "kubernetes_namespace" "autoscaling_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = kubernetes_namespace.autoscaling_namespace.metadata[0].name

  set {
    name  = "awsRegion"
    value = var.cluster_region
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = var.service_accout_name
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eks_node_autoscaling_aim_role.arn
  }

  set {
    name  = "extraArgs.leader-elect"
    value = "true"
  }

  set {
    name  = "extraArgs.unremovable-node-recheck-timeout"
    value = "1m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_autoscaling_aim_role_policy_attach
  ]
}
