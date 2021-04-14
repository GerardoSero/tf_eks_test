terraform {
  required_version = ">=0.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.22.0"
    }
  }
}

locals {
  node_group_name = "${var.cluster_name}-${var.name}"
}

data "aws_ami" "eks_node_ami" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.node_ami_version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

resource "aws_launch_template" "eks_node_lt" {
  name                   = "${local.node_group_name}-lt"
  image_id               = data.aws_ami.eks_node_ami.id
  instance_type          = "t3.medium"
  update_default_version = true
  key_name               = var.node_key_name
  vpc_security_group_ids = [var.node_security_group_id]

  user_data = base64encode(
    <<EOL
#!/bin/bash
set -ex
B64_CLUSTER_CA=${var.cluster_ca}
API_SERVER_URL=${var.cluster_endpoint}
/etc/eks/bootstrap.sh ${var.cluster_name} \
  --kubelet-extra-args '--node-labels=eks.amazonaws.com/nodegroup-image=${data.aws_ami.eks_node_ami.id},\eks.amazonaws.com/capacityType=ON_DEMAND,eks.amazonaws.com/nodegroup=${local.node_group_name}' \
  --b64-cluster-ca $B64_CLUSTER_CA \
  --apiserver-endpoint $API_SERVER_URL
  
EOL
  )

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 30
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Cluster = var.cluster_name
    }
  }

  monitoring {
    enabled = true
  }

  lifecycle {
    ignore_changes = [block_device_mappings]
  }
}


# Worker Node Group

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = var.cluster_name
  node_group_name = local.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  launch_template {
    id      = aws_launch_template.eks_node_lt.id
    version = aws_launch_template.eks_node_lt.latest_version
  }

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
