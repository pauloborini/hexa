# INDEX: FEATURE

Módulos do hexa: um diretório em `Sources/Hexa/Services/`, views em `Sources/Hexa/UI/`, alvo próprio no `Package.swift` quando for helper.

## Required

1. `project-rules/rules/operational_rules.md` — gates de build/teste de cada mudança
2. `project-rules/rules/on-demand-architecture.md` — todo comportamento de módulo é sob demanda

## On trigger

- `on-demand-architecture.md`: timer, polling, callback em fundo, leitura na menu bar, amostragem com painel.
- `repo-hygiene.md`: commit, push, remoção, identificadores de defaults e paths de suporte.
- `index/shared.md`: quando a tarefa toca infra compartilhada (Core, Support, plumbing).

Load every triggered rule before the first edit, in batches of up to two.
