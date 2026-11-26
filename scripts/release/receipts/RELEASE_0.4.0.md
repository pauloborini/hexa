# Release v0.4.0 - 2026-11-26

## Metadados

- Versão: 0.4.0 (build 4)
- Tag planejada: v0.4.0, ainda não criada
- Data prevista: 2026-11-26
- Branch de release: release/v0.4.0
- SHA-base: 25ce7959a7162d91abd136d36eab408c85dc066d
- SHA final em main: pendente
- Plataforma: macOS 14 ou posterior, arm64
- GitHub Release: https://github.com/pauloborini/hexa/releases/tag/v0.4.0, pendente
- Feed Sparkle: https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml, pendente
- Homebrew Cask: permanece em 0.3.0 até a publicação
- DMG: hexa-0.4.0-arm64.dmg, ainda não gerado
- SHA-256 do DMG: pendente
- Notarização do app e do DMG: pendente
- Smoke arm64 R1-R3: pendente
- Backup EdDSA: criar ou validar antes da publicação

## O que há de novo

- Novo Gerenciador de janelas com atalhos configuráveis, grade visual, ciclo de posições e arrasto magnético.
- Captura com tela congelada e seleção de janela por clique, com OCR, detecção de códigos e edição mais eficientes.
- Controle de monitores externos mais confiável com DDC, adaptadores HDMI e luz do teclado.
- Métricas de disco com extração nativa de E/S.
- Desinstalação em lote por seleção explícita de apps, incluindo operação única confirmada para casks do Homebrew.

## Notas públicas

### pt-BR

O Hexa 0.4.0 adiciona o Gerenciador de janelas, melhora captura, OCR e controle de monitores, e permite analisar vários apps na mesma desinstalação sem pré-selecionar nada. O módulo novo fica disponível em Recursos e não é instalado automaticamente na atualização.

### en-US

Hexa 0.4.0 adds the Window Manager, improves capture, OCR and external display control, and lets you scan several apps in one uninstall batch without preselecting anything. The new module is available in Features and is not installed automatically during an update.

## Estado da release

- PR #17 integrado em develop no SHA 25ce7959a7162d91abd136d36eab408c85dc066d.
- Anti-vazamento A/B, scan de segredos, swift build, swift test com 801 testes e zero falhas, e ./build.sh --release passaram antes da integração.
- DMG oficial, assinatura Developer ID, notarização, appcast, smoke, tag e publicação ainda pendentes.
