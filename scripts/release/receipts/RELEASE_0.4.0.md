# Release v0.4.0 - 2026-11-26

## Metadados

- Versão: 0.4.0 (build 4)
- Tag: v0.4.0, anotada no SHA final de main e publicada
- Data prevista: 2026-11-26
- Branch de release: release/v0.4.0
- SHA-base: 25ce7959a7162d91abd136d36eab408c85dc066d
- SHA final em main: b215d21bbe8568927d9bc0028f31ddf3f56d2a2b
- Plataforma: macOS 14 ou posterior, arm64
- GitHub Release: https://github.com/pauloborini/hexa/releases/tag/v0.4.0, publicada
- Feed Sparkle: https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml, HTTP 200 com enclosure versionado e assinatura EdDSA
- Homebrew Cask: 0.4.0 com sha256 do DMG publicado
- DMG: hexa-0.4.0-arm64.dmg, gerado, assinado e notarizado
- SHA-256 do DMG: 57c23e0587d888b1a0b959f25330ed1a125c28d999030b6f4b9e417e7dfdd6f0
- Notarização do app e do DMG: aceita pela Apple, staple validado
- Smoke arm64 R1-R3: aprovado em máquina arm64 macOS 27.2, registro validado por smoke_record.py
- Backup EdDSA: criado e verificado fora do repositório antes da publicação

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
- PR #18 integrada em main no merge commit b215d21bbe8568927d9bc0028f31ddf3f56d2a2b.
- DMG oficial build 4 no SHA final de main, assinatura Developer ID, notarização, appcast EdDSA e smoke R1-R3 concluídos.
- Tag v0.4.0 publicada; GitHub Release com appcast.xml, DMG, release.json e SHA256SUMS; feed latest público validado.
