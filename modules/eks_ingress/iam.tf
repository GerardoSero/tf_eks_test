resource "aws_iam_policy" "eks_externaldns_policy" {
  count = var.external_dns_enabled ? 1 : 0

  name        = "${var.external_dns.cluster_name}-cloudwatch"
  path        = "/"
  description = "CloudWatch Policy for ${var.external_dns.cluster_name}"

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
  count = var.external_dns_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.external_dns.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:${var.service_account_name}"]
    }

    principals {
      identifiers = [var.external_dns.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_externaldns_aim_role" {
  count = var.external_dns_enabled ? 1 : 0

  name               = "${var.external_dns.cluster_name}-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.eks_externaldns_policy_document[0].json
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_aim_role_policy_attach" {
  count = var.external_dns_enabled ? 1 : 0

  role       = aws_iam_role.eks_externaldns_aim_role[0].name
  policy_arn = aws_iam_policy.eks_externaldns_policy[0].arn
}
