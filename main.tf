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

module "eks_autoscaling" {
  source            = "./modules/eks_autoscaling"
  cluster_name      = module.eks.cluster.id
  cluster_region    = var.aws_region
  oidc_provider_url = module.eks.oidc_provider_url
  oidc_provider_arn = module.eks.oidc_provider_arn
  overprovisioning  = var.eks_overprovisioning_enabled ? "linear" : "disabled"

  depends_on = [
    module.eks_node_groups
  ]
}

module "eks_cloudwatch" {
  count = var.eks_cloudwatch_enabled ? 1 : 0

  source            = "./modules/eks_cloudwatch"
  cluster_name      = module.eks.cluster.id
  cluster_region    = var.aws_region
  oidc_provider_url = module.eks.oidc_provider_url
  oidc_provider_arn = module.eks.oidc_provider_arn

  depends_on = [
    module.eks_node_groups
  ]
}

module "eks_ingress" {
  count = var.ingress_type != "none" ? 1 : 0

  source               = "./modules/eks_ingress"
  ingress_type         = var.ingress_type
  external_dns_enabled = var.ingress_external_dns_enabled
  external_dns = {
    cluster_name      = module.eks.cluster.id
    cluster_region    = var.aws_region
    oidc_provider_url = module.eks.oidc_provider_url
    oidc_provider_arn = module.eks.oidc_provider_arn
    public_domain     = var.public_domain
  }

  depends_on = [
    module.eks_node_groups
  ]
}

module "k8s" {
  source             = "./modules/k8s"
  prometheus_enabled = var.prometheus_enabled
  ingress_type       = var.ingress_type
  grafana_host       = "grafana.${var.public_domain}"

  depends_on = [
    module.eks_node_groups
  ]
}

module "k8s_test_services" {
  count = var.k8s_test_services_enabled ? 1 : 0

  source        = "./modules/k8s_test_services"
  ingress_type  = var.ingress_type
  public_domain = var.public_domain

  depends_on = [
    module.eks_node_groups
  ]
}
