# ADR-003: Estratégia de Autenticação — Dual Identity (Admin + Customer)

**Status**: Aceito  
**Data**: 2026-04-21  
**Autores**: Time de Arquitetura

---

## Contexto

O sistema de oficina mecânica (`auto-repair-shop`) suporta dois tipos distintos de atores:

1. **Administradores** — funcionários da oficina que gerenciam ordens de serviço, cadastram clientes e veículos, aprovam pagamentos, etc.
2. **Clientes** — donos dos veículos que consultam status de ordens de serviço e histórico de manutenções.

O sistema legado (`fiap-13soat-auto-repair-shop-app-deprecated`) implementava autenticação de admin via email+senha com armazenamento em banco relacional, e autenticação de cliente via CPF via Lambda. Na migração para microserviços, foi necessário definir uma nova estratégia de autenticação que:

- Fosse centralizada (não replicar lógica de auth em cada serviço)
- Usasse JWT para ser stateless nos serviços downstream
- Mantivesse a separação entre as duas identidades de domínio
- Funcionasse com o API Gateway AWS (HTTP API v2)

---

## Decisão

### Arquitetura: Auth Service Centralizado + JWT HS256

```mermaid
graph LR
    AdminClient([Admin\nPostman/App]) -->|email+password| GW
    CustomerClient([Customer\nApp]) -->|CPF| GW

    subgraph "API Gateway (AWS HTTP API v2)"
        GW[API Gateway] -->|POST /api/auth/login\nPOST /api/auth/register\nPOST /api/auth/refresh| AuthSvc[Auth Service]
        GW -->|POST /api/auth/cpf| Lambda[Lambda\nCPF Auth]
        GW -->|ANY /api/{proxy+}\n+ JWT Authorizer| ALB[ALB → Microservices]
    end

    AuthSvc -->|JWT type:'admin'| AdminClient
    Lambda -->|JWT type:'customer'| CustomerClient

    ALB --> CV[Customer-Vehicle :3001]
    ALB --> WO[Work-Order :3002]
    ALB --> BI[Billing :3003]
    ALB --> EX[Execution :3004]
```

### Dois Fluxos de Autenticação

#### Fluxo Admin (email + senha)

```
POST /api/auth/register → cria admin (PBKDF2 hash da senha)
POST /api/auth/login    → verifica credenciais → JWT (accessToken 15m + refreshToken 7d)
POST /api/auth/refresh  → rotação do refreshToken
```

JWT Admin emitido:

```json
{
  "sub": "<uuid>",
  "type": "admin",
  "role": "ADMIN",
  "name": "...",
  "email": "..."
}
```

#### Fluxo Customer (CPF)

```
POST /api/auth/cpf → valida CPF → busca customer → JWT (accessToken 15m, sem refresh)
```

JWT Customer emitido:

```json
{
  "sub": "<uuid>",
  "type": "customer",
  "cpf": "...",
  "name": "...",
  "email": "..."
}
```

### Autorização nos Microserviços

Todos os 4 microserviços implementam um hook `onRequest` Fastify que:

1. Valida a assinatura JWT (HS256, mesmo secret compartilhado)
2. Verifica `issuer` e `audience`
3. Para métodos de escrita (`POST`, `PUT`, `PATCH`, `DELETE`): exige `type === 'admin'`
4. Para leitura (`GET`, `HEAD`): aceita qualquer token válido (admin ou customer)

```typescript
// Pseudocódigo do auth-hook
if (WRITE_METHODS.has(request.method) && decoded.type !== "admin") {
  reply.status(403).send({ error: "Admin privileges required" });
}
```

### Algoritmo JWT

- **Algoritmo**: HS256 (HMAC-SHA256)
- **Issuer**: `https://auto-repair-shop.auth`
- **Audience**: `auto-repair-shop-api`
- **Access Token expiry**: 15 minutos
- **Refresh Token expiry**: 7 dias (com rotação — o refresh token é invalidado após uso)

---

## Alternativas Consideradas

### 1. Cognito (AWS) como IdP

**Prós**: Gerenciado, MFA out-of-the-box, OIDC padrão, admin console  
**Contras**: Complexidade adicional, custo (free tier limitado), lock-in AWS, overhead para FIAP challenge acadêmico  
**Decisão**: Descartado para o escopo do projeto, mas recomendado para produção real.

### 2. Auth Service Separado (microserviço dedicado)

**Prós**: Responsabilidade única, escalabilidade independente  
**Contras**: Mais um serviço para manter, overhead de deployment, latência adicional  
**Decisão**: Para o volume atual, o auth-service embutido no local-env + Lambda em produção é suficiente. Um Auth Service dedicado seria o próximo passo natural.

### 3. JWT RS256 (chave assimétrica)

**Prós**: Serviços downstream podem validar sem conhecer a chave privada  
**Contras**: Mais complexo de configurar (rotação de chaves, distribuição de JWKs), não necessário para o modelo de deployment atual  
**Decisão**: HS256 com shared secret é adequado enquanto os serviços estão no mesmo VPC e compartilham o secret via variáveis de ambiente/Secrets Manager.

### 4. Auth Distribuído (cada serviço implementa)

**Prós**: Nenhuma dependência de serviço central  
**Contras**: Duplicação de lógica, inconsistência de implementação, difícil de auditar  
**Decisão**: Descartado. Todos os serviços delegam _emissão_ de token ao auth-service; _validação_ é local (stateless, sem rede).

---

## Consequências

### Positivas

- **Stateless**: Microserviços validam JWT localmente (sem chamada ao auth-service)
- **Simples**: HS256 com shared secret, sem PKI
- **Separação de identidade**: `type` no JWT permite RBAC claro (admin vs customer)
- **Compatível com API Gateway**: Lambda Authorizer usa o mesmo algoritmo e secret
- **Extensível**: Novos roles podem ser adicionados ao claim `type` sem mudança de infraestrutura

### Negativas / Riscos

- **Revogação de token**: Sem blacklist — tokens admin são válidos até expirar (15min). Para revogação imediata, seria necessário um token blacklist (Redis).
- **Secret compartilhado**: Todos os serviços conhecem o secret de assinatura. Se vazado, todos os tokens são comprometidos.
- **Admin em memória (local)**: O auth-service local perde admins ao reiniciar. Em produção, usa PostgreSQL.

### Mitigações Recomendadas para Produção

- Armazenar `JWT_ACCESS_TOKEN_SECRET` no AWS Secrets Manager (não como variável de ambiente em texto)
- Implementar Redis para blacklist de tokens (logout imediato)
- Considerar migração para RS256 + JWKs endpoint
- Avaliar Cognito para MFA e compliance

---

## Referências

- [RFC 7519 — JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [AWS API Gateway JWT Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html)
- Legado: `fiap-13soat-auto-repair-shop-app-deprecated/src/main/routes/auth-routes.ts`
