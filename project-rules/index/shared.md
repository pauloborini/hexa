# INDEX: SHARED

Infra compartilhada do hexa: Core, Support, plumbing de processos, hotkeys, defaults e permissões.

## Required

1. `project-rules/rules/on-demand-architecture.md` — qualquer coisa que rodeia, agenda ou amostra
2. `project-rules/rules/repo-hygiene.md` — versionamento, segredos, commits

## On trigger

- `on-demand-architecture.md`: timer, polling, callback em fundo, leitura na menu bar.
- `repo-hygiene.md`: commit, push, remoção, qualquer conteúdo que cite projeto, app ou serviço de terceiros.
- `design-system.md`: mudança na camada de tema/tokens (`Support`/`Core`) que alimenta views (DEC-017).

Load every triggered rule before the first edit, in batches of up to two.
