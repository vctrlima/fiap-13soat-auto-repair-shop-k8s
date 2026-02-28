# K8s Infrastructure

Terraform modules for provisioning the Kubernetes cluster and supporting AWS infrastructure.

## What This Provisions

- **VPC**: Public/private subnets across 2 AZs, NAT Gateways, route tables
- **EKS**: Managed Kubernetes cluster with configurable node group
- **IAM**: Roles for EKS, IRSA (Secrets Manager, ALB Controller)
- **ALB**: Application Load Balancer with health-check target group
- **API Gateway**: HTTP API with JWT authorizer, VPC Link, route configuration
- **Secrets Manager**: Application secrets store

> **Note**: The Lambda authentication function (CPF auth) has been moved to a separate repository: [`fiap-13soat-auto-repair-shop-lambda`](https://github.com/fiap-13soat/fiap-13soat-auto-repair-shop-lambda). This project reads Lambda outputs via `terraform_remote_state`. The Lambda must be provisioned **before** this infrastructure.

## Module Structure

```
/terraform/
├── main.tf                  # Root module + Secrets Manager resources
├── variables.tf             # Input variables
├── outputs.tf               # Exported values
├── modules/
│   ├── network/             # VPC, subnets, NAT, routes
│   ├── eks/                 # EKS cluster, node group, OIDC
│   ├── iam/                 # IAM roles, policies, IRSA
│   ├── alb/                 # Load balancer, target group
│   └── api-gateway/         # HTTP API, routes, authorizer
└── environments/
    ├── staging/
    │   └── terraform.tfvars
    └── production/
        └── terraform.tfvars
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- S3 bucket for state: `auto-repair-shop-terraform-state`
- DynamoDB table for locking: `auto-repair-shop-terraform-locks`
- Lambda infrastructure provisioned first ([`fiap-13soat-auto-repair-shop-lambda`](https://github.com/fiap-13soat/fiap-13soat-auto-repair-shop-lambda))

## Usage

```bash
cd fiap-13soat-auto-repair-shop-k8s/terraform

# Initialize
terraform init

# Plan (staging)
terraform plan -var-file=environments/staging/terraform.tfvars

# Apply (production)
terraform plan -var-file=environments/production/terraform.tfvars -out=tfplan
terraform apply tfplan
```

## Key Outputs

| Output                 | Description                             |
| ---------------------- | --------------------------------------- |
| `cluster_name`         | EKS cluster name                        |
| `cluster_endpoint`     | EKS API endpoint                        |
| `alb_dns_name`         | ALB DNS for health checks               |
| `api_gateway_endpoint` | Public API URL                          |
| `auth_lambda_arn`      | CPF auth Lambda ARN (from remote state) |
| `secrets_manager_name` | Application secrets ARN                 |

## Environment Configurations

| Parameter          | Staging     | Production  |
| ------------------ | ----------- | ----------- |
| Node instance type | t3.small    | t3.medium   |
| Min nodes          | 1           | 1           |
| Max nodes          | 3           | 5           |
| VPC CIDR           | 10.1.0.0/16 | 10.0.0.0/16 |

## Deployment

Deployed via GitHub Actions (`.github/workflows/cd.yml`) with manual approval gate for the `production` environment.
