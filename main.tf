module "eks" {
  source            = "./modules/eks"
  cluster_name      = var.cluster_name
  cluster_version   = "1.16"
  admin_access_cidr = var.admin_access_cidr
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group_rule" "eks_node_sg-workstation-ssh" {
  description       = "Allow workstation to communicate with the nodes"
  security_group_id = module.eks.nodes_sg.id
  cidr_blocks       = [var.admin_access_cidr]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  type              = "ingress"
}

locals {
  nodes = {
    node-group-116 = "1.16"
    #node-group-117 = "1.17"
  }
}

module "eks_node_groups" {
  for_each = local.nodes

  source                 = "./modules/eks_node_group"
  name                   = each.key
  subnet_ids             = module.eks.subnet_ids
  cluster_name           = module.eks.cluster.id
  cluster_ca             = module.eks.cluster.certificate_authority[0].data
  cluster_endpoint       = module.eks.cluster.endpoint
  node_role_arn          = module.eks.node_role_arn
  node_key_name          = aws_key_pair.ec2_key.key_name
  node_security_group_id = module.eks.nodes_sg.id
  node_ami_version       = each.value
}

module "k8s" {
  source              = "./modules/k8s"
  cluster_id          = module.eks.cluster.id # creates dependency on cluster creation
  autoscaler_role_arn = module.eks.autoscaler_role_arn
}
