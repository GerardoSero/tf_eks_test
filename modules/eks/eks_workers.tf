# Worker Node IAM Role

resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# AutoScaling
data "tls_certificate" "eks_cluster_oidc_tls" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_cluster_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_oidc_tls.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
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

# Worker Node Security Group

resource "aws_security_group" "eks_node_sg" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.eks_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map(
    "Name", "${var.cluster_name}-node-sg",
    "kubernetes.io/cluster/${var.cluster_name}", "owned"
  )

}

resource "aws_security_group_rule" "eks_node_sg-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_node_sg-cluster-https" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_node_sg-cluster-others" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  to_port                  = 65535
  type                     = "ingress"
}

# Worker Node Access to EKS Master Cluster

resource "aws_security_group_rule" "eks_node_sg-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_node_sg-workstation-ssh" {
  description       = "Allow workstation to communicate with the nodes"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = [var.admin_access_cidr]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  type              = "ingress"
}


resource "aws_key_pair" "eks_node_key" {
  key_name   = "${var.cluster_name}-node-key"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Cluster = var.cluster_name
  }
}

locals {
  eks_node_group_116_name = "${aws_eks_cluster.eks_cluster.name}-node-group-116"
}

data "aws_ami" "eks_node_ami_116" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-1.16-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

resource "aws_launch_template" "eks_node_lt_116" {
  name                   = "${local.eks_node_group_116_name}-lt"
  image_id               = data.aws_ami.eks_node_ami_116.id
  instance_type          = "t3.medium"
  update_default_version = true
  key_name               = aws_key_pair.eks_node_key.key_name
  vpc_security_group_ids = [aws_security_group.eks_node_sg.id]

  user_data = base64encode(
    <<EOL
#!/bin/bash
set -ex
B64_CLUSTER_CA=${aws_eks_cluster.eks_cluster.certificate_authority[0].data}
API_SERVER_URL=${aws_eks_cluster.eks_cluster.endpoint}
/etc/eks/bootstrap.sh ${aws_eks_cluster.eks_cluster.name} \
  --kubelet-extra-args '--node-labels=eks.amazonaws.com/nodegroup-image=${data.aws_ami.eks_node_ami_116.id},\eks.amazonaws.com/capacityType=ON_DEMAND,eks.amazonaws.com/nodegroup=${local.eks_node_group_116_name}' \
  --b64-cluster-ca $B64_CLUSTER_CA \
  --apiserver-endpoint $API_SERVER_URL
  
EOL
  )

  # block_device_mappings {
  #   device_name = "/dev/sda1"

  #   ebs {
  #     volume_size = 20
  #   }
  # }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Cluster = var.cluster_name
    }
  }

  monitoring {
    enabled = true
  }
}


# Worker Node Group

resource "aws_eks_node_group" "eks_node_group_116" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = local.eks_node_group_116_name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id

  launch_template {
    id      = aws_launch_template.eks_node_lt_116.id
    version = aws_launch_template.eks_node_lt_116.latest_version
  }

  scaling_config {
    desired_size = 4
    max_size     = 5
    min_size     = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_role_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEC2ContainerRegistryReadOnly,
  ]

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
