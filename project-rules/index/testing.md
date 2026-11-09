# INDEX: TESTING

Criação, alteração e execução de testes (`Tests/`); `swift test` fecha o gate quando o alvo tem testes.

## Required

1. `project-rules/rules/operational_rules.md` — gates de build e teste

## On trigger

- `on-demand-architecture.md`: teste não agenda trabalho em fundo no app; amostragem permanece presa à visibilidade do painel.
- `index/shared.md`: quando o teste cobre infra compartilhada.

Load every triggered rule before the first edit, in batches of up to two.
