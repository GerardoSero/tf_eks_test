resource "aws_iam_policy" "eks_cloudwatch_policy" {
  name        = "${var.cluster_name}-cloudwatch"
  path        = "/"
  description = "CloudWatch Policy for ${var.cluster_name}"

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Action" = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        "Resource" = "*"
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "ssm:GetParameter"
        ],
        "Resource" = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      }
    ]
  })
}

data "aws_iam_policy_document" "eks_cloudwatch_policy_document" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_cloudwatch_aim_role" {
  name               = "${var.cluster_name}-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.eks_cloudwatch_policy_document.json
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_aim_role_policy_attach" {
  role       = aws_iam_role.eks_cloudwatch_aim_role.name
  policy_arn = aws_iam_policy.eks_cloudwatch_policy.arn
}
