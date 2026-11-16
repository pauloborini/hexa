# Release v0.2.0 - 2026-11-16

## Metadados

- Versão: `0.2.0` (build `2`)
- Tag: `v0.2.0`
- Branches: `codex/release-v0.2.0` -> `develop` -> `main`
- SHA-base: `ff4db74d30fbcb2741a4e8ed8d1d9032f3c512af`
- SHA final em `main`: pendente de revisão e integração
- Plataforma: macOS 14 ou posterior, arm64
- GitHub Release: pendente
- Feed Sparkle: `https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml`
- Homebrew Cask: pendente
- DMG e checksum: pendentes do build no SHA final de `main`
- Notarização: pendente
- Smoke arm64 R1-R3: validado no Mac Apple M5 Pro, evidências em `.app-work/guides/UPDATER_INITIAL_ROLLOUT_GUIDE/evidence/`
- Backup EdDSA AES-256: criado e comparado com a chave atual do Chaveiro; senha armazenada no Chaveiro

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
- PR de integração para `develop`: pendente.
- PR de promoção de `develop` para `main`: pendente.
- Tag, GitHub Release, publicação do appcast e atualização do Cask: pendentes.
