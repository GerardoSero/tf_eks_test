output "cluster" {
  value = aws_eks_cluster.eks_cluster
}

output "node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "nodes_sg" {
  value = aws_security_group.eks_node_sg
}

output "subnet_ids" {
  value = aws_subnet.eks_subnet[*].id
}

output "oidc_provider_url" {
  value = aws_iam_openid_connect_provider.eks_cluster_oidc_provider.url
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks_cluster_oidc_provider.arn
}