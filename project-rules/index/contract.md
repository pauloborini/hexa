# INDEX: CONTRACT

DTOs, mappers e contratos de feed/updater (ex.: feed de atualização do app, saída de processo do brew).

## Required

1. `project-rules/rules/repo-hygiene.md` — paths de arquivo, identificadores de defaults e nomes de bundle não vazam para logs
2. `project-rules/rules/operational_rules.md` — gates de build de cada mudança

## On trigger

- `repo-hygiene.md`: qualquer conteúdo que cite projeto, app ou serviço de terceiros.

Load every triggered rule before the first edit, in batches of up to two.
