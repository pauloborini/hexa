# Release v0.2.0 - 2026-11-16

## Metadados

- Versão: `0.2.0` (build `2`)
- Tag: `v0.2.0`
- Branches: `codex/release-v0.2.0` -> `develop` -> `main`
- SHA-base: `ff4db74d30fbcb2741a4e8ed8d1d9032f3c512af`
- SHA do commit de release em `main`: `08e716b15e86c6a4246e28bb27183cc02ba67d02`
- Plataforma: macOS 14 ou posterior, arm64
- GitHub Release: https://github.com/pauloborini/hexa/releases/tag/v0.2.0
- Feed Sparkle: `https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml`
- Homebrew Cask: `0.2.0`, integrado em `develop` pelo PR #3 e em `main` pelo PR #4
- DMG: `hexa-0.2.0-arm64.dmg`
- SHA-256 do DMG: `29264d8854946b6826cc80081fe8bd3bf893e84130d29dd707de3279b63e2ca8`
- Notarização do app: aceita
- Notarização do DMG: aceita
- Smoke arm64 R1-R3: validado no Mac Apple M5 Pro.
- Backup EdDSA AES-256: criado e comparado com a chave atual do Chaveiro; senha armazenada no Chaveiro.

## O que há de novo

- Verificação e instalação de atualizações pelo app, somente após confirmação do usuário.
- Melhora a confiabilidade das atualizações assinadas instaladas pelo próprio Hexa.

## Notas públicas

### pt-BR

Verifique atualizações em Sobre e instale uma nova versão somente após sua confirmação. O fluxo de instalação de atualizações assinadas também está mais confiável.

### en-US

Check for updates in About and install a new version only after you confirm. Signed updates installed from the app are more reliable.

## Estado da release

- Smoke R1-R3 em uma máquina arm64: validado pelo gate atualizado.
- Backup EdDSA: validado fora do repositório.
- Tag `v0.2.0`, DMG e `appcast.xml`: publicados e validados.
- Cask 0.2.0: integrado em `develop` e `main`; histórico sincronizado pelo PR #5.
