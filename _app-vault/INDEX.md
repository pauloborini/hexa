---
vault_version: 1
updated: 2026-11-09
scope: decisões de produto do hexa (escopo, comportamento, design do notch, licença, identidade e design system)
---

# hexa — vault index

## Domains

- [escopo-do-app](docs/decisions/escopo-do-app.md) — os módulos do escopo, comportamento sob demanda, menu bar configurável e ocultação de ícones, Homebrew, idiomas, telemetria, primeira execução e contagem não repetida
- [dynamic-island](docs/decisions/dynamic-island.md) — Controles como interface padrão e não ocultável, escolha do que a ilha fechada mostra, Reproduzindo Agora opt-in, tamanho do notch e barra de atalhos
- [uninstaller](docs/decisions/uninstaller.md) — seleção de sobras e atalho selecionar tudo
- [licenca-e-identidade](docs/decisions/licenca-e-identidade.md) — licença GPL, código-fonte público, release no repositório público, identidade própria e design system

- [versionamento](docs/decisions/versionamento.md) — versão pública inicial beta e fonte canônica

## Specs (contexto técnico, não decisão)

- [specs/design-system](specs/design-system.md) — registro canônico de tokens, tipografia, geometria, matriz de contraste e primitives (DEC-017)

## Guias (documentação pública, não decisão)

Explicam o app para quem lê o repositório. Em conflito com uma DEC, vale a DEC e o guia é corrigido.

- [guides/architecture](docs/guides/architecture.md) — princípios, ciclo de vida dos módulos, controle térmico e organização do código
- [guides/building](docs/guides/building.md) — requisitos, alvos do SwiftPM, compilação, gate de segredos e contribuição
- [guides/modules](docs/guides/modules.md) — o que cada módulo faz e como desinstalar o Hexa
- [guides/permissions](docs/guides/permissions.md) — permissões do macOS, quem usa, quando são pedidas e efeito da recusa

## Valid features

`app-updates`, `monitor`, `uninstaller`, `cleaner`, `maintenance-tasks`, `media-tools`, `dynamic-island`, `mixer`, `keep-awake`, `keyboard-light`, `screen-brightness`, `kill-process`, `port-manager`, `screen-capture`

## By feature

- app-updates → escopo-do-app, licenca-e-identidade, versionamento
- monitor → escopo-do-app, licenca-e-identidade, versionamento
- uninstaller → escopo-do-app, uninstaller, licenca-e-identidade, versionamento
- cleaner → escopo-do-app, licenca-e-identidade, versionamento
- maintenance-tasks → escopo-do-app, licenca-e-identidade, versionamento
- media-tools → escopo-do-app, licenca-e-identidade, versionamento
- dynamic-island → escopo-do-app, dynamic-island, licenca-e-identidade, versionamento
- mixer → escopo-do-app, licenca-e-identidade, versionamento
- keep-awake → escopo-do-app, licenca-e-identidade, versionamento
- keyboard-light → escopo-do-app, licenca-e-identidade, versionamento
- screen-brightness → escopo-do-app, licenca-e-identidade, versionamento
- kill-process → escopo-do-app, licenca-e-identidade, versionamento
- port-manager → escopo-do-app, licenca-e-identidade, versionamento
- screen-capture → escopo-do-app, licenca-e-identidade, versionamento
