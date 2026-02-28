# Production environment configuration
environment        = "production"
region             = "us-east-1"
project_name       = "auto-repair-shop"
cluster_name       = "auto-repair-shop-cluster"
kubernetes_version = "1.34"

# Production-grade instances
node_instance_type = "t3.medium"
node_desired_count = 2
node_min_count     = 1
node_max_count     = 5

# Networking
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]

app_port = 3000

tags = {
  Project     = "auto-repair-shop"
  ManagedBy   = "terraform"
  Environment = "production"
}
