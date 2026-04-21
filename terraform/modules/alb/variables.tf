variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "resource_suffix" {
  type = string
}

# app_port removed — each service has a dedicated port (3001–3004)

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "eks_nodes_security_group_id" {
  type = string
}

variable "eks_cluster_security_group_id" {
  type = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
  default     = ""
}
