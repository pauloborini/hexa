# INDEX: NAVIGATION

Fluxo entre módulos e painéis: status item, painel único, janela de settings, superfícies da ilha.

## Required

1. `project-rules/rules/on-demand-architecture.md` — abrir superfície liga a amostragem dela; fechar desliga
2. `project-rules/rules/operational_rules.md` — gates de build de cada mudança

## On trigger

- Índice do tipo `ui`: quando o fluxo altera views/painéis.
- `index/shared.md`: quando o fluxo toca permissões, defaults ou plumbing.

Load every triggered rule before the first edit, in batches of up to two.
