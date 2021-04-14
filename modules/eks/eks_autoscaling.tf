# AutoScaling

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
      variable = "${replace(aws_iam_openid_connect_provider.eks_cluster_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_cluster_oidc_provider.arn]
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
