# ADR-001: Adoção da AWS como Provedor de Nuvem

## Status

Aceito

## Contexto

O projeto Auto Repair Shop precisa de uma infraestrutura em nuvem para hospedar a aplicação, banco de dados, funções serverless e o API Gateway. A escolha do provedor de nuvem impacta diretamente o custo, a disponibilidade de serviços gerenciados, a curva de aprendizado da equipe e a escalabilidade da solução.

Provedores avaliados:

- **AWS (Amazon Web Services)**
- **GCP (Google Cloud Platform)**
- **Azure (Microsoft Azure)**

## Decisão

Adotamos a **AWS** como provedor de nuvem principal para toda a infraestrutura do projeto.

## Justificativa

1. **Maturidade dos serviços gerenciados**: AWS oferece EKS, RDS, Lambda e API Gateway como serviços maduros, bem documentados e amplamente adotados no mercado.
2. **Ecossistema Terraform**: O provider AWS do Terraform é o mais maduro e documentado, com cobertura ampla de recursos.
3. **OIDC nativo com GitHub Actions**: AWS suporta federação de identidade via OIDC para CI/CD sem credenciais de longa duração, aumentando a segurança.
4. **Familiaridade da equipe**: A equipe possui experiência prévia com serviços AWS, reduzindo o tempo de ramp-up.
5. **Free Tier**: AWS oferece Free Tier para muitos serviços, facilitando o desenvolvimento e testes com menor custo.

## Consequências

- **Positivas**: Infraestrutura confiável, ampla documentação, integração nativa com ferramentas de CI/CD e observabilidade.
- **Negativas**: Vendor lock-in parcial com serviços como EKS, RDS e Lambda. Mitigado pela abstração via Terraform e uso de padrões abertos (OpenTelemetry, JWT).

## Alternativas Consideradas

| Provedor | Prós                            | Contras                                                        |
| -------- | ------------------------------- | -------------------------------------------------------------- |
| GCP      | GKE superior, BigQuery          | Menor market share, menor familiaridade da equipe              |
| Azure    | Integração com Active Directory | Maior complexidade de configuração, custo potencialmente maior |
