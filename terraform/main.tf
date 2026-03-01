# =============================================================================
# K8s Infrastructure - Main Configuration
# Provisions EKS cluster, networking, ALB, IAM, Secrets Manager, API Gateway
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "auto-repair-shop-terraform-state"
    region         = "us-east-2"
    dynamodb_table = "auto-repair-shop-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
}

# -----------------------------------------------------------------------------
# Modules
# -----------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name        = var.cluster_name
}

module "iam" {
  source = "./modules/iam"

  project_name    = var.project_name
  resource_suffix = local.resource_suffix
  eks_oidc_issuer = module.eks.oidc_issuer
  eks_oidc_arn    = module.eks.oidc_provider_arn
  secrets_manager_secret_arn = aws_secretsmanager_secret.app.arn
}

module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  resource_suffix    = local.resource_suffix

  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  node_instance_type = var.node_instance_type
  node_desired_count = var.node_desired_count
  node_min_count     = var.node_min_count
  node_max_count     = var.node_max_count

  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_nodes_role_arn   = module.iam.eks_nodes_role_arn

  depends_on = [module.iam]
}

module "alb" {
  source = "./modules/alb"

  project_name    = var.project_name
  environment     = var.environment
  resource_suffix = local.resource_suffix
  app_port        = var.app_port

  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  eks_nodes_security_group_id   = module.eks.nodes_security_group_id
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
}

# -----------------------------------------------------------------------------
# Remote State - Lambda Infrastructure
# -----------------------------------------------------------------------------

data "terraform_remote_state" "lambda" {
  backend = "s3"

  config = {
    bucket = "auto-repair-shop-terraform-state"
    key    = "lambda-infrastructure/${var.environment}/terraform.tfstate"
    region = "us-east-2"
  }
}

module "api_gateway" {
  source = "./modules/api-gateway"

  project_name    = var.project_name
  environment     = var.environment
  resource_suffix = local.resource_suffix

  alb_listener_arn  = module.alb.listener_arn
  alb_dns_name      = module.alb.dns_name
  vpc_id            = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id

  lambda_invoke_arn    = data.terraform_remote_state.lambda.outputs.invoke_arn
  lambda_function_name = data.terraform_remote_state.lambda.outputs.function_name

  jwt_access_token_secret = var.jwt_access_token_secret
}

# -----------------------------------------------------------------------------
# Secrets Manager (shared across app and Lambda)
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.project_name}/app-secrets-${local.resource_suffix}"
  description             = "Application secrets for ${var.project_name}"
  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = {
    Name = "${var.project_name}-app-secrets-${local.resource_suffix}"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DB_USER                  = var.db_username
    DB_PASSWORD              = var.db_password
    DB_HOST                  = var.db_host
    DB_PORT                  = tostring(var.db_port)
    DB_NAME                  = var.db_name
    DATABASE_URL             = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_name}?schema=public"
    JWT_ACCESS_TOKEN_SECRET  = var.jwt_access_token_secret
    JWT_REFRESH_TOKEN_SECRET = var.jwt_refresh_token_secret
    SMTP_USERNAME            = var.smtp_username
    SMTP_PASSWORD            = var.smtp_password
  })
}
