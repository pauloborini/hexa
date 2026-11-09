# INDEX: DIAGNOSTIC

Investigação e correção de bug: o critério é o que reproduz o defeito e o que prova a correção.

## Required

1. `project-rules/rules/operational_rules.md` — gates de build/teste de cada mudança

## On trigger

- `on-demand-architecture.md`: diagnóstico não autoriza polling em fundo para "observar melhor".
- `index/shared.md`: quando o defeito atravessa Core, Support ou plumbing.
- Registro: defeito confirmado entra em `.app-work/issues/` (`ISSUE-NNN`).

Load every triggered rule before the first edit, in batches of up to two.
