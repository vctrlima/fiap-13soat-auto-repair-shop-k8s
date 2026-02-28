# =============================================================================
# K8s Infrastructure - Outputs
# =============================================================================

# --- EKS ---
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority" {
  description = "Certificate authority data for the EKS cluster"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}"
}

# --- Networking ---
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

# --- ALB ---
output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.dns_name
}

output "target_group_arn" {
  description = "Target Group ARN for EKS pods"
  value       = module.alb.target_group_arn
}

# --- API Gateway ---
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.api_endpoint
}

# --- IAM ---
output "secrets_manager_role_arn" {
  description = "IAM Role ARN for K8s ServiceAccount to access Secrets Manager"
  value       = module.iam.secrets_manager_role_arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = module.iam.load_balancer_controller_role_arn
}

# --- Secrets Manager ---
output "secrets_manager_arn" {
  description = "Secrets Manager secret ARN"
  value       = aws_secretsmanager_secret.app.arn
}

output "secrets_manager_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.app.name
}

# --- Lambda (from remote state) ---
output "auth_lambda_arn" {
  description = "Authentication Lambda function ARN"
  value       = data.terraform_remote_state.lambda.outputs.function_arn
}

output "auth_lambda_function_name" {
  description = "Authentication Lambda function name"
  value       = data.terraform_remote_state.lambda.outputs.function_name
}
