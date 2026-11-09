# INDEX: UI

Views, painéis, layouts e componentes em `Sources/Hexa/UI/` (SwiftUI; AppKit para status item e popover).

## Required

1. `project-rules/rules/operational_rules.md` — gates de build de cada mudança
2. `project-rules/rules/design-system.md` — tokens, primitives e contraste (DEC-017); registro em `_app-vault/specs/design-system.md`

## On trigger

- `on-demand-architecture.md`: painel aberto liga a amostragem dele; fechou, desliga. Sem cache em fundo para "abrir mais rápido".
- `index/shared.md`: quando a view consome permissões, defaults ou plumbing compartilhado.

Load every triggered rule before the first edit, in batches of up to two.
