variable "project_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "resource_suffix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_instance_type" {
  type = string
}

variable "node_desired_count" {
  type = number
}

variable "node_min_count" {
  type = number
}

variable "node_max_count" {
  type = number
}

variable "eks_cluster_role_arn" {
  type = string
}

variable "eks_nodes_role_arn" {
  type = string
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access the EKS API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
