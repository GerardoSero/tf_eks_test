resource "aws_iam_policy" "eks_externaldns_policy" {
  name        = "${var.cluster_name}-cloudwatch"
  path        = "/"
  description = "CloudWatch Policy for ${var.cluster_name}"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource" : [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

data "aws_iam_policy_document" "eks_externaldns_policy_document" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:${var.service_account_name}"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_externaldns_aim_role" {
  name               = "${var.cluster_name}-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.eks_externaldns_policy_document.json
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_aim_role_policy_attach" {
  role       = aws_iam_role.eks_externaldns_aim_role.name
  policy_arn = aws_iam_policy.eks_externaldns_policy.arn
}
