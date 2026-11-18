# Release v0.3.0 - 2026-11-18

## Metadados

- Versão: 0.3.0 (build 3)
- Tag: v0.3.0
- Data: 2026-11-18
- Branch de release: release/v0.3.0
- SHA-base: 55dbaf925f78102b7a950032f6e20d69fa1e580a
- SHA final em main: 50270b76b6fae34a2226fec183adb99963c4acf8
- Plataforma: macOS 14 ou posterior, arm64
- GitHub Release: https://github.com/pauloborini/hexa/releases/tag/v0.3.0
- Feed Sparkle: https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml
- Homebrew Cask: versão 0.3.0 preparada após a publicação
- DMG: hexa-0.3.0-arm64.dmg
- SHA-256 do DMG: 969a609e15bed120747725977b039657a51c875a67b09a36028e9cbe85352ee4
- Notarização do app e do DMG: aceita pela Apple; tickets stapled e validados
- Smoke arm64 R1-R3: validado em uma máquina arm64
- Backup EdDSA AES-256: criado fora do repositório, aberto e comparado com a chave atual do Chaveiro

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

- PR #12 integrado em develop e PR #13 integrado em main no SHA 50270b76b6fae34a2226fec183adb99963c4acf8.
- Scan de segredos, swift build, swift test (708 testes, 0 falhas), ./build.sh --release e compilação arm64 passaram.
- DMG oficial assinado, notarizado e validado; appcast Sparkle assinado para o enclosure versionado.
- Tag v0.3.0 publicada no SHA final de main; GitHub Release e feed Sparkle publicados com todos os assets exigidos.
