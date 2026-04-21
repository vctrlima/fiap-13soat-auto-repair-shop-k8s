variable "project_name" {
  type = string
}

variable "resource_suffix" {
  type = string
}

variable "eks_oidc_issuer" {
  type = string
}

variable "eks_oidc_arn" {
  type = string
}

variable "secrets_manager_secret_arns" {
  description = "ARNs of Secrets Manager secrets to grant access to"
  type        = list(string)
}
