output "cluster" {
  value = aws_eks_cluster.eks_cluster
}

output "autoscaler_role_arn" {
  value = aws_iam_role.eks_node_autoscaling_aim_role.arn
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