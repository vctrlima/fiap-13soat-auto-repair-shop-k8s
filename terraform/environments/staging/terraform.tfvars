# Staging environment configuration
environment        = "staging"
region             = "us-east-1"
project_name       = "auto-repair-shop"
cluster_name       = "auto-repair-shop-staging"
kubernetes_version = "1.34"

# Smaller instances for staging
node_instance_type = "t3.small"
node_desired_count = 1
node_min_count     = 1
node_max_count     = 3

# Networking
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.20.0/24"]

app_port = 3000

tags = {
  Project     = "auto-repair-shop"
  ManagedBy   = "terraform"
  Environment = "staging"
}
