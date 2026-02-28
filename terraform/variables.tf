# =============================================================================
# K8s Infrastructure - Variables
# =============================================================================

# --- Project ---
variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "auto-repair-shop"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

# --- EKS ---
variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "auto-repair-shop-cluster"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

# --- Networking ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# --- Application ---
variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 3000
}

# --- Database (consumed from database-infrastructure outputs) ---
variable "db_host" {
  description = "RDS database hostname (from database-infrastructure output)"
  type        = string
}

variable "db_port" {
  description = "RDS database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "auto_repair_shop"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

# --- Auth / Secrets ---
variable "jwt_access_token_secret" {
  description = "Secret key for JWT access tokens"
  type        = string
  sensitive   = true
}

variable "jwt_refresh_token_secret" {
  description = "Secret key for JWT refresh tokens"
  type        = string
  sensitive   = true
}

variable "smtp_username" {
  description = "SMTP username for email functionality"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP password for email functionality"
  type        = string
  default     = ""
  sensitive   = true
}

# --- Tags ---
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "auto-repair-shop"
    ManagedBy = "terraform"
  }
}
