output "cluster" {
  value = aws_eks_cluster.eks_cluster
}

output "autoscaler_role_arn" {
  value = aws_iam_role.eks_node_autoscaling_aim_role.arn
}