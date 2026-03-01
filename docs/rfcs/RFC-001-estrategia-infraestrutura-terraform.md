# RFC-002: Estratégia de Infraestrutura e Provisionamento com Terraform

## Metadados

| Campo         | Valor                   |
| ------------- | ----------------------- |
| **Autor**     | Equipe Auto Repair Shop |
| **Data**      | 2026-01-10              |
| **Status**    | Aprovado                |
| **Revisores** | Equipe de Arquitetura   |

## Resumo

Esta RFC define a estratégia de provisionamento de infraestrutura utilizando Terraform, incluindo a separação em repositórios, a organização modular, o gerenciamento de estado remoto e a integração com CI/CD.

## Motivação

O sistema Auto Repair Shop requer infraestrutura para VPC, EKS, RDS, Lambda, API Gateway e serviços auxiliares. A infraestrutura precisa ser:

- Reproduzível e versionada
- Separada por domínio (rede, compute, dados, serverless)
- Multi-ambiente (staging, production)
- Provisionável automaticamente via CI/CD

## Proposta Detalhada

### Separação em Repositórios

A infraestrutura é dividida em 4 repositórios, cada um com seu ciclo de vida e pipeline CI/CD independentes:

```
fiap-13soat-auto-repair-shop-k8s/       → VPC, EKS, ALB, API Gateway, IAM, Secrets Manager
fiap-13soat-auto-repair-shop-db/        → RDS PostgreSQL, Security Groups, Monitoring
fiap-13soat-auto-repair-shop-lambda/    → Lambda Function, IAM Role, CloudWatch Logs
fiap-13soat-auto-repair-shop-app/       → Aplicação (K8s manifests, Dockerfile, CI/CD)
```

### Ordem de Provisionamento

```
1. k8s (network, EKS, ALB, API Gateway) → Outputs: VPC/subnets, cluster endpoint, ALB ARN
2. lambda (function, IAM) → Outputs: function ARN, invoke ARN
3. db (RDS) → Depende de: VPC/subnets do k8s
4. app (deploy K8s) → Depende de: EKS cluster, RDS endpoint, Lambda ARN
```

### Dependências via Remote State

Os repositórios compartilham dados via `terraform_remote_state`:

```hcl
# No repo DB — lê outputs do K8s
data "terraform_remote_state" "k8s_infra" {
  backend = "s3"
  config = {
    bucket = "auto-repair-shop-terraform-state"
    key    = "k8s-infrastructure/${var.environment}/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Estado Remoto

| Aspecto         | Configuração                               |
| --------------- | ------------------------------------------ |
| **Backend**     | S3 (um bucket por projeto)                 |
| **Locking**     | DynamoDB (previne applies concorrentes)    |
| **Encryption**  | AES-256 server-side encryption             |
| **Key pattern** | `{domain}/{environment}/terraform.tfstate` |

### Organização Modular (Repo K8s)

```
terraform/
├── main.tf                            # Root module — orquestra módulos
├── variables.tf                       # Variáveis globais
├── outputs.tf                         # Outputs para remote state
├── environments/
│   ├── staging/terraform.tfvars       # Valores staging
│   └── production/terraform.tfvars    # Valores produção
└── modules/
    ├── network/     # VPC, subnets, NAT, IGW, routes
    ├── iam/         # Roles, policies, IRSA
    ├── eks/         # EKS cluster, node group, OIDC
    ├── alb/         # ALB, target group, listeners
    └── api-gateway/ # HTTP API, routes, JWT authorizer
```

### Multi-Ambiente

| Aspecto             | Staging     | Production  |
| ------------------- | ----------- | ----------- |
| Instância EKS       | t3.small    | t3.medium   |
| Nós (min/max)       | 1/3         | 1/5         |
| VPC CIDR            | 10.1.0.0/16 | 10.0.0.0/16 |
| RDS instância       | db.t3.micro | db.t3.small |
| Deletion protection | Não         | Sim         |

### CI/CD com GitHub Actions

Todos os repositórios utilizam:

- **OIDC Role Assumption**: Sem credenciais de longa duração
- **Concurrency groups**: Previne applies concorrentes por ambiente
- **Manual approval**: Produção requer aprovação manual (via GitHub Environments)
- **Pipeline**: `fmt check` → `init` → `validate` → `plan` → `apply`

## Impacto

- **Rastreabilidade**: Toda mudança de infra é versionada e revisável via PR
- **Segurança**: OIDC elimina secrets de longa duração; state criptografado
- **Reprodutibilidade**: Ambientes idênticos provisionados pelo mesmo código
- **Independência**: Cada domínio evolui com seu próprio ciclo de deploy

## Riscos e Mitigações

| Risco                   | Mitigação                                               |
| ----------------------- | ------------------------------------------------------- |
| State corruption        | S3 versioning + DynamoDB locking                        |
| Drift entre ambientes   | Code review obrigatório, var-files separados            |
| Dependências circulares | Remote state unidirecional, ordem de deploy documentada |

## Decisão

Aprovado conforme proposto. Implementação concluída nos 4 repositórios com pipelines CI/CD funcionais.
