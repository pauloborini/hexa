# Release v0.3.0 - 2026-11-18

## Metadados

- Versão: 0.3.0 (build 3)
- Tag planejada: v0.3.0, ainda não criada
- Data prevista: 2026-11-18
- Branch de release: release/v0.3.0
- SHA-base: 55dbaf925f78102b7a950032f6e20d69fa1e580a
- SHA final em main: pendente
- Plataforma: macOS 14 ou posterior, arm64
- GitHub Release: https://github.com/pauloborini/hexa/releases/tag/v0.3.0, pendente
- Feed Sparkle: https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml, pendente
- Homebrew Cask: permanece em 0.2.0 até a publicação
- DMG: hexa-0.3.0-arm64.dmg, ainda não gerado
- SHA-256 do DMG: pendente
- Notarização do app e do DMG: pendente
- Smoke arm64 R1-R3: pendente
- Backup EdDSA: validar novamente antes da publicação

## O que há de novo

- Alterne a seção oculta da menu bar por atalho global; clique fora fecha a revelação e novos prazos de recolhimento são aplicados.
- Apps iniciados enquanto a seção está fechada permanecem ocultos até serem movidos.
- Cleaner identifica melhor a propriedade dos bundles e para a varredura quando ela é cancelada.
- Métricas de disco resolvem a identidade nativamente e descartam amostras antigas.
- A desinstalação move sobras bloqueadas com segurança e para quando você cancela.

## Notas públicas

### pt-BR

Alterne a seção oculta da menu bar por atalho global e controle melhor quando ela se recolhe. Cleaner e Monitor lidam melhor com cancelamentos e leituras de disco. A desinstalação para quando você cancela e trata sobras em uso com mais segurança.

### en-US

Toggle the hidden menu bar section with a global shortcut and control when it closes. Cleaner and Monitor handle cancellation and disk readings more reliably. Uninstall stops when you cancel and safely handles leftovers that are still in use.

## Estado da release

- PR #12 integrado em develop no SHA 55dbaf925f78102b7a950032f6e20d69fa1e580a.
- Scan de segredos, swift build, swift test (708 testes, 0 falhas) e ./build.sh --release passaram localmente.
- Os produtos arm64 foram compilados e confirmados. O build está marcado como dirty por causa das alterações ainda não commitadas.
- DMG oficial, assinatura Developer ID, notarização, smoke, tag e publicação ainda pendentes.
