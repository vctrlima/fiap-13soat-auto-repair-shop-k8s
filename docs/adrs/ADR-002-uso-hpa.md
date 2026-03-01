# ADR-002: Uso de HPA (Horizontal Pod Autoscaler) para Escalabilidade

## Status

Aceito

## Contexto

A aplicação Auto Repair Shop é executada em um cluster Kubernetes (EKS) e precisa lidar com variações de carga de trabalho — especialmente nos horários de pico de abertura e acompanhamento de ordens de serviço. É necessário definir a estratégia de escalabilidade para garantir disponibilidade sem desperdício de recursos.

Estratégias avaliadas:

- **Escalabilidade manual** (número fixo de réplicas)
- **VPA (Vertical Pod Autoscaler)** — ajuste de CPU/memória por pod
- **HPA (Horizontal Pod Autoscaler)** — ajuste do número de réplicas
- **KEDA (Kubernetes Event-Driven Autoscaling)** — escalabilidade baseada em eventos

## Decisão

Adotamos o **HPA (Horizontal Pod Autoscaler)** com métricas de CPU (70%) e memória (80%), mínimo de 2 réplicas e máximo de 10.

## Justificativa

1. **Nativo do Kubernetes**: HPA é um recurso nativo do Kubernetes, sem dependências externas.
2. **Alta disponibilidade**: Mínimo de 2 réplicas garante zero downtime em caso de falha de um pod.
3. **Eficiência de custos**: Escala automaticamente com a demanda, evitando over-provisioning.
4. **Configuração de estabilização**: Scale-up em 60s para resposta rápida, scale-down em 300s para evitar flapping.
5. **Métricas duplas**: Uso combinado de CPU e memória para decisões mais precisas de escalabilidade.

## Configuração

```yaml
minReplicas: 2
maxReplicas: 10
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60
  scaleDown:
    stabilizationWindowSeconds: 300
```

## Consequências

- **Positivas**: Alta disponibilidade, resposta automática a picos de carga, custos otimizados.
- **Negativas**: Requer Metrics Server instalado no cluster. Limitado a métricas de recursos (CPU/memória) sem custom metrics adapter.

## Alternativas Consideradas

| Estratégia | Prós                        | Contras                                      |
| ---------- | --------------------------- | -------------------------------------------- |
| Manual     | Simples, previsível         | Não responde a variações de carga            |
| VPA        | Otimiza recursos por pod    | Requer restart de pods para aplicar mudanças |
| KEDA       | Event-driven, mais granular | Complexidade adicional, dependência externa  |
