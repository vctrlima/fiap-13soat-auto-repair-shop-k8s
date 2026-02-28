variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "resource_suffix" {
  type = string
}

variable "app_port" {
  type = number
}

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
