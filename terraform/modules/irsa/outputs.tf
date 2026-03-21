output "secrets_manager_role_arn" {
  value = aws_iam_role.secrets_manager_access.arn
}

output "load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}
