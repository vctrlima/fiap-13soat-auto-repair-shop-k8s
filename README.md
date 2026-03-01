# Auto Repair Shop — K8s Infrastructure

Terraform modules for provisioning the core AWS infrastructure: VPC, EKS cluster, IAM roles (IRSA), Application Load Balancer, API Gateway (HTTP API with JWT authorizer), and Secrets Manager. This is the **foundation** of the Auto Repair Shop ecosystem and must be deployed first.

> **Part of the [Auto Repair Shop](https://github.com/fiap-13soat) ecosystem.**
> Deploy order: **K8s Infra (this repo)** → Lambda → DB → App

---

## Table of Contents

- [Purpose](#purpose)
- [Architecture](#architecture)
- [Technologies](#technologies)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [CI/CD & Deployment](#cicd--deployment)
- [API Documentation](#api-documentation)
- [Related Repositories](#related-repositories)

---

## Purpose

This repository provisions all the AWS infrastructure required to run the Auto Repair Shop system:

- **VPC** with public and private subnets across 2 Availability Zones, NAT Gateways, and route tables
- **EKS** managed Kubernetes cluster with configurable node group for running the application
- **IAM** roles for EKS, and IRSA (IAM Roles for Service Accounts) for Secrets Manager and ALB Controller
- **ALB** (Application Load Balancer) with health-check target group, fronting the EKS cluster
- **API Gateway** (HTTP API v2) — single entry point for all clients, with JWT authorizer, VPC Link to ALB, and Lambda integration for CPF authentication
- **Secrets Manager** for securely storing and syncing application secrets to Kubernetes via ExternalSecrets

---

## Architecture

### Infrastructure & Kubernetes Overview

```mermaid
graph TB
    Client([Client]) --> APIGW

    subgraph "AWS Cloud"
        APIGW[API Gateway HTTP API<br/>JWT Authorizer]

        subgraph "VPC (2 AZs)"
            subgraph "Public Subnets"
                NAT[NAT Gateway]
                ALB[Application Load Balancer]
            end

            subgraph "Private Subnets"
                Lambda[Lambda - CPF Auth]
                RDS[(RDS PostgreSQL 16)]

                subgraph "EKS Cluster (auto-repair-shop-cluster)"

                    subgraph "Namespace: auto-repair-shop"
                        SA[ServiceAccount<br/>external-secrets-sa]
                        CM[ConfigMap<br/>auto-repair-shop-config]
                        ExtSecret[ExternalSecret<br/>auto-repair-shop-secret]
                        TGB[TargetGroupBinding<br/>auto-repair-shop-tgb]

                        subgraph "Deployment: auto-repair-shop (2-10 replicas)"
                            Pod1[Pod<br/>Fastify App :3000]
                            Pod2[Pod<br/>Fastify App :3000]
                        end

                        SVC[Service ClusterIP<br/>auto-repair-shop-service :80]
                        HPA[HPA<br/>CPU 70% / Mem 80%]
                    end

                    subgraph "Namespace: monitoring"
                        OTELCol[OTEL Collector<br/>gRPC :4317 / HTTP :4318]
                        OTELProm[Prometheus Exporter :8889]
                    end

                end
            end
        end

        VPCLink[VPC Link]
        SM[AWS Secrets Manager]
        IAM[IAM / IRSA Roles]
        ECR[ECR Repository]
    end

    %% External traffic
    APIGW -- "POST /api/auth/cpf" --> Lambda
    APIGW -- "ANY /api/{proxy+}\n(JWT protected)" --> VPCLink
    APIGW -- "GET /health, /docs/*\n(public)" --> VPCLink
    VPCLink --> ALB

    %% ALB to K8s
    ALB -- "TargetGroupBinding\n(target-type: ip)" --> TGB
    TGB --> SVC
    SVC -- "port 80 → 3000" --> Pod1
    SVC -- "port 80 → 3000" --> Pod2

    %% HPA controls scaling
    HPA -. "scales" .-> Pod1
    HPA -. "scales" .-> Pod2

    %% Config injection
    CM -. "envFrom" .-> Pod1
    CM -. "envFrom" .-> Pod2
    ExtSecret -. "secretKeyRef" .-> Pod1
    ExtSecret -. "secretKeyRef" .-> Pod2

    %% ServiceAccount → IRSA
    SA -. "IRSA" .-> IAM
    IAM -. "assume role" .-> SM

    %% Secrets sync
    SM -- "sync secrets" --> ExtSecret

    %% Pod → external
    Pod1 --> RDS
    Pod2 --> RDS
    Pod1 -- "OTLP" --> OTELCol
    Pod2 -- "OTLP" --> OTELCol
    OTELCol --> OTELProm
    Lambda --> RDS

    %% ECR pull
    ECR -. "image pull" .-> Pod1
    ECR -. "image pull" .-> Pod2

    %% Outbound
    Pod1 --> NAT
    Pod2 --> NAT

    style APIGW fill:#ff9900,stroke:#cc7a00,color:#fff
    style ALB fill:#ff9900,stroke:#cc7a00,color:#fff
    style VPCLink fill:#ff9900,stroke:#cc7a00,color:#fff
    style Lambda fill:#ff9900,stroke:#cc7a00,color:#fff
    style SM fill:#ff9900,stroke:#cc7a00,color:#fff
    style IAM fill:#dd344c,stroke:#b52a3e,color:#fff
    style ECR fill:#ff9900,stroke:#cc7a00,color:#fff
    style RDS fill:#336791,stroke:#1a3d5c,color:#fff
    style Pod1 fill:#326ce5,stroke:#1a4db5,color:#fff
    style Pod2 fill:#326ce5,stroke:#1a4db5,color:#fff
    style SVC fill:#326ce5,stroke:#1a4db5,color:#fff
    style HPA fill:#326ce5,stroke:#1a4db5,color:#fff
    style TGB fill:#326ce5,stroke:#1a4db5,color:#fff
    style SA fill:#326ce5,stroke:#1a4db5,color:#fff
    style CM fill:#326ce5,stroke:#1a4db5,color:#fff
    style ExtSecret fill:#326ce5,stroke:#1a4db5,color:#fff
    style OTELCol fill:#4caf50,stroke:#388e3c,color:#fff
    style OTELProm fill:#4caf50,stroke:#388e3c,color:#fff
```

### Kubernetes Components Detail

```mermaid
graph LR
    subgraph "Namespace: auto-repair-shop"
        direction TB

        subgraph "Configuration"
            CM2[ConfigMap<br/>SERVER_HOST, SERVER_PORT<br/>NODE_ENV, SMTP_*, OTEL_*]
            ES[ExternalSecret<br/>DB creds, JWT secrets<br/>SMTP creds]
            SS[SecretStore<br/>AWS Secrets Manager]
        end

        subgraph "Workload"
            SA2[ServiceAccount<br/>IRSA annotated]
            Deploy[Deployment<br/>auto-repair-shop<br/>RollingUpdate<br/>maxUnavailable: 0<br/>maxSurge: 1]
            Pods[Pods x2-10<br/>Fastify :3000<br/>liveness: /health<br/>readiness: /health]
        end

        subgraph "Networking"
            SVC2[Service ClusterIP<br/>:80 → :3000]
            TGB2[TargetGroupBinding<br/>target-type: ip]
        end

        subgraph "Scaling"
            HPA2[HPA<br/>min: 2 / max: 10<br/>CPU 70% / Mem 80%<br/>scaleUp: 60s window<br/>scaleDown: 300s window]
        end
    end

    SS -- "provider: aws" --> SM2[AWS Secrets Manager]
    ES -- "refreshInterval: 1h" --> SS
    ES -- "creates" --> Secret2[K8s Secret<br/>auto-repair-shop-secret]

    SA2 -- "IRSA" --> IAM2[IAM Role]

    CM2 -. "envFrom" .-> Pods
    Secret2 -. "secretKeyRef" .-> Pods
    SA2 -. "serviceAccountName" .-> Deploy
    Deploy -- "manages" --> Pods
    HPA2 -- "scales" --> Deploy
    Pods -- "selector" --> SVC2
    SVC2 --> TGB2
    TGB2 -- "registers IPs" --> ALB2[ALB Target Group]

    style Deploy fill:#326ce5,stroke:#1a4db5,color:#fff
    style Pods fill:#326ce5,stroke:#1a4db5,color:#fff
    style SVC2 fill:#326ce5,stroke:#1a4db5,color:#fff
    style HPA2 fill:#326ce5,stroke:#1a4db5,color:#fff
    style TGB2 fill:#326ce5,stroke:#1a4db5,color:#fff
    style SA2 fill:#326ce5,stroke:#1a4db5,color:#fff
    style CM2 fill:#326ce5,stroke:#1a4db5,color:#fff
    style ES fill:#326ce5,stroke:#1a4db5,color:#fff
    style SS fill:#326ce5,stroke:#1a4db5,color:#fff
    style Secret2 fill:#326ce5,stroke:#1a4db5,color:#fff
    style SM2 fill:#ff9900,stroke:#cc7a00,color:#fff
    style IAM2 fill:#dd344c,stroke:#b52a3e,color:#fff
    style ALB2 fill:#ff9900,stroke:#cc7a00,color:#fff
```

### API Gateway Routing

| Route                | Target          | Auth         |
| -------------------- | --------------- | ------------ |
| `POST /api/auth/cpf` | Lambda function | Public       |
| `ANY /api/{proxy+}`  | ALB → EKS       | JWT required |
| `GET /health`        | ALB → EKS       | Public       |
| `GET /docs/{proxy+}` | ALB → EKS       | Public       |

### Module Dependency Graph

```mermaid
graph LR
    Network[Network Module] --> EKS[EKS Module]
    Network --> ALB[ALB Module]
    Network --> IAM[IAM Module]
    EKS --> IAM
    EKS --> APIGateway[API Gateway Module]
    ALB --> APIGateway
    IAM --> APIGateway
    LambdaState[(Lambda Remote State)] -.-> APIGateway

    style Network fill:#232f3e,stroke:#131920,color:#fff
    style EKS fill:#326ce5,stroke:#1a4db5,color:#fff
    style ALB fill:#ff9900,stroke:#cc7a00,color:#fff
    style APIGateway fill:#ff9900,stroke:#cc7a00,color:#fff
    style IAM fill:#dd344c,stroke:#b52a3e,color:#fff
```

---

## Technologies

| Technology          | Version | Purpose                                    |
| ------------------- | ------- | ------------------------------------------ |
| **Terraform**       | ≥ 1.5.0 | Infrastructure as Code                     |
| **AWS EKS**         | —       | Managed Kubernetes cluster                 |
| **AWS VPC**         | —       | Network isolation (2 AZs, NAT)             |
| **AWS ALB**         | —       | Application Load Balancer                  |
| **AWS API GW v2**   | —       | HTTP API with JWT authorizer & VPC Link    |
| **AWS IAM**         | —       | Roles, policies, IRSA for pod-level access |
| **AWS Secrets Mgr** | —       | Application secrets store                  |
| **AWS Provider**    | ~5.0    | Terraform AWS resource management          |
| **TLS Provider**    | ~4.0    | TLS certificate handling                   |
| **S3**              | —       | Terraform state backend                    |
| **DynamoDB**        | —       | Terraform state locking                    |
| **GitHub Actions**  | —       | CI/CD pipeline                             |

---

## Project Structure

```
├── terraform/
│   ├── main.tf                    # Root module + Secrets Manager resources
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Exported values
│   ├── modules/
│   │   ├── network/               # VPC, subnets, NAT, route tables
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── eks/                   # EKS cluster, managed node group, OIDC
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── iam/                   # IAM roles, policies, IRSA
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── alb/                   # Load balancer, target group
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── api-gateway/           # HTTP API, routes, JWT authorizer, VPC Link
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── environments/
│       ├── staging/
│       │   ├── terraform.tfvars   # Staging configuration
│       │   └── backend.hcl        # Staging state backend config
│       └── production/
│           ├── terraform.tfvars   # Production configuration
│           └── backend.hcl        # Production state backend config
```

---

## Getting Started

### Prerequisites

- Terraform ≥ 1.5.0
- AWS CLI configured with appropriate credentials
- S3 bucket for state: `auto-repair-shop-terraform-state`
- DynamoDB table for locking: `auto-repair-shop-terraform-locks`

> **This is the first repository to deploy** in the ecosystem. No prior infrastructure is needed.

### Terraform Commands

```bash
cd terraform

# Initialize with backend config
terraform init -backend-config=environments/staging/backend.hcl

# Plan (staging)
terraform plan -var-file=environments/staging/terraform.tfvars

# Plan (production)
terraform plan -var-file=environments/production/terraform.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

### Key Outputs

| Output                 | Description                             |
| ---------------------- | --------------------------------------- |
| `cluster_name`         | EKS cluster name                        |
| `cluster_endpoint`     | EKS API endpoint                        |
| `alb_dns_name`         | ALB DNS for health checks               |
| `api_gateway_endpoint` | Public API URL                          |
| `auth_lambda_arn`      | CPF auth Lambda ARN (from remote state) |
| `secrets_manager_name` | Application secrets ARN                 |

### Environment Configurations

| Parameter          | Staging     | Production  |
| ------------------ | ----------- | ----------- |
| Node instance type | t3.small    | t3.medium   |
| Min nodes          | 1           | 1           |
| Max nodes          | 3           | 5           |
| VPC CIDR           | 10.1.0.0/16 | 10.0.0.0/16 |

---

## CI/CD & Deployment

Deployed via GitHub Actions (`.github/workflows/deploy-infra.yml`):

| Stage          | Trigger                               | Approval             |
| -------------- | ------------------------------------- | -------------------- |
| **Staging**    | Push to `main` (path: `terraform/**`) | Automatic            |
| **Production** | After staging succeeds                | Manual approval gate |

The pipeline uses **OIDC-based AWS credential assumption** (no long-lived access keys).

---

## API Documentation

This is an infrastructure repository that provisions the **API Gateway** as the public entry point. It does not serve APIs directly.

For the full API documentation (Swagger UI), see the application repository:

> **Swagger UI**: Available at `http://localhost:3000/docs` when running the [App](https://github.com/vctrlima/fiap-13soat-auto-repair-shop-app).

---

## Related Repositories

This project is part of the **Auto Repair Shop** ecosystem. Deploy in this order:

| #   | Repository                                                                                                  | Description                                     |
| --- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| 1   | **`fiap-13soat-auto-repair-shop-k8s`** (this repo)                                                          | AWS infrastructure (VPC, EKS, ALB, API Gateway) |
| 2   | [`fiap-13soat-auto-repair-shop-lambda`](https://github.com/vctrlima/fiap-13soat-auto-repair-shop-lambda) | CPF authentication Lambda function              |
| 3   | [`fiap-13soat-auto-repair-shop-db`](https://github.com/vctrlima/fiap-13soat-auto-repair-shop-db)         | Database infrastructure (RDS PostgreSQL)        |
| 4   | [`fiap-13soat-auto-repair-shop-app`](https://github.com/vctrlima/fiap-13soat-auto-repair-shop-app)       | Application API                                 |
