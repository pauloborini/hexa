# INDEX: SECURITY

Segredo, PII, permissões e ambiente: grants do sistema, execução de processo, XPC privilegiado, defaults.

## Required

1. `project-rules/rules/repo-hygiene.md` — nunca versionar segredo, credencial, token ou PII
2. `project-rules/rules/operational_rules.md` — gates de build de cada mudança

## On trigger

- `on-demand-architecture.md`: permissões e comportamento sob demanda são invariantes aprovados (salvo mudança explícita).
- `index/shared.md`: quando a mudança toca `Permissions`, execução de processo ou ambiente sanitizado.

Load every triggered rule before the first edit, in batches of up to two.
