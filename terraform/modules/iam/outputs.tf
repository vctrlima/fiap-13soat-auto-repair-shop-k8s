output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_nodes_role_arn" {
  value = aws_iam_role.eks_nodes.arn
}

output "secrets_manager_role_arn" {
  value = aws_iam_role.secrets_manager_access.arn
}

output "load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}
