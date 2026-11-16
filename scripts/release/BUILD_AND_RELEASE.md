# Contrato de build e release do Hexa

## Versão e alvos

- Fonte canônica da versão: `Sources/Hexa/Resources/ReleaseVersion.txt`.
- Sincronizar a versão com `CHANGELOG.md`, `release.json`, tag e Homebrew Cask.
- Alvo público: app macOS arm64 em DMG assinado com Developer ID e notarizado pela Apple.
- Destino: GitHub Releases em `pauloborini/hexa`; o mesmo DMG serve para instalação manual e Sparkle.
- O asset `appcast.xml` usa o enclosure versionado do DMG e a assinatura EdDSA.
- `Casks/hexa.rb` aponta para o DMG da tag pública e é atualizado depois da publicação.

## Branches, revisão e tags

- O repositório usa Gitflow: `develop` é a integração e `main` recebe releases públicas.
- Neste rollout inicial, a branch de trabalho aprovada pelo operador abre PR para `develop`; depois `develop` abre PR para `main`.
- Usar merge commit (`--no-ff`) para preservar o histórico de release.
- Branches protegidas exigem as aprovações configuradas no GitHub. Não contornar proteção, mesmo para administradores.
- Criar a tag anotada `vX.Y.Z` somente depois do PR para `main`, no SHA final validado.
- Após a publicação e a atualização do Cask, sincronizar `main` para `develop` por PR quando o histórico de integração exigir.
- O bootstrap v0.2.0 é a primeira release com updater; não criar release de teste pública para validar Sparkle.
- Rodar análise, testes e build local antes dos PRs. Gerar o pacote oficial no SHA validado de `main` depois da integração, pois `prepare_dmg.py` exige que a branch atual seja `main`.

## Smoke e evidências

- Executar o smoke numa única máquina macOS arm64 disponível ao mantenedor. Não exigir matriz por geração, classe mapeada ou chip fora do mapa.
- O registro de smoke valida os critérios R1, R2 e R3 do rollout, com arquivo de evidência existente para cada um.
- Não usar obrigações OBL de roadmaps externos como gate de publicação.
- Guardar o registro em `.app-work/smoke/X.Y.Z/RECORD.md`, fora do Git. O script `smoke_record.py` valida a versão, arm64, a atestação do operador e os caminhos de evidência.
- O smoke em uma geração não declara validação de recursos específicos de hardware em todas as gerações.

## Gates

1. Ler o estado de `main`, `develop`, tags, proteções e PRs antes de qualquer mudança remota.
2. Rodar `scripts/release/check-secrets.sh` e as classes A e B do gate anti-vazamento antes do build. Classe B de Flutter é não aplicável a este app Swift.
3. Rodar `swift build`, `swift test`, `./build.sh` e os testes dos scripts de release afetados.
4. Fazer backup criptografado da chave privada EdDSA fora do repositório e validar que a imagem abre e contém a chave atual antes de publicar. Nunca versionar a chave ou a senha.
5. Gerar DMG de distribuição em `.app-work/releases/`, confirmar arm64, assinatura, checksum e notarização. Rodar a classe C no app e no DMG.
6. Confirmar que o smoke record é válido antes de abrir ou publicar a release.
7. Abrir os PRs na ordem definida, aguardar revisões e gates do GitHub, integrar sem bypass, e só então criar a tag e publicar.

## Comandos de distribuição

O perfil local usa o ambiente Python em `.app-work/releases/.venv` para instalar os requisitos declarados:

```bash
python3 -m venv .app-work/releases/.venv
.app-work/releases/.venv/bin/python -m pip install -r scripts/release/requirements.txt
./build.sh --release
scripts/release/build-release.sh .app-work/releases/release-products
python3 scripts/release/prepare_dmg.py --app build/hexa.app --build N
python3 scripts/release/notarize.py .app-work/releases/X.Y.Z --keychain-profile hexa-notary
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin .app-work/releases/.venv/bin/python scripts/release/feed_prepare.py .app-work/releases/X.Y.Z/hexa-X.Y.Z-arm64.dmg X.Y.Z --workdir .app-work/releases/X.Y.Z/feed
git tag -a vX.Y.Z -m "Release X.Y.Z"
git push origin vX.Y.Z
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin .app-work/releases/.venv/bin/python scripts/release/publish.py .app-work/releases/X.Y.Z --repo pauloborini/hexa --notes .app-work/releases/RELEASE_X.Y.Z.md --smoke-approved --smoke-record .app-work/smoke/X.Y.Z/RECORD.md --appcast .app-work/releases/X.Y.Z/feed/appcast.xml --publish
python3 scripts/release/write_cask.py .app-work/releases/X.Y.Z
```

`N` é o número de build inteiro da versão e `X.Y.Z` é a versão canônica. Antes de `publish.py`, confirmar que `main`, tag e `release.json` apontam para o mesmo SHA. O publisher cria o rascunho, anexa o feed e só remove o rascunho quando os dois assets exigidos estão presentes.

## Backup da chave EdDSA

- Gerar o backup com `scripts/release/sparkle_keys.py export --image <caminho-fora-do-repo>` e digitar uma senha no prompt. Para automação, a senha pode entrar por stdin com `--password-file -`. O comando recusa sobrescrever uma imagem existente.
- O fluxo local armazena uma senha aleatória no Chaveiro do macOS, serviço `com.pauloborini.hexa.sparkle.backup`, conta `eddsa-encryption-passphrase`. A senha nunca vai para argumento de processo, terminal ou arquivo temporário.
- A senha da imagem é um item separado. Não alterar a ACL do item `Private key for signing Sparkle updates` para exportar ou verificar o backup.
- Manter o acesso da chave restrito às ferramentas Sparkle já autorizadas no Chaveiro. Não selecionar acesso por todos os aplicativos.
- Recuperar a senha para validação por pipe: `/usr/bin/security find-generic-password -s com.pauloborini.hexa.sparkle.backup -a eddsa-encryption-passphrase -w | SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin .app-work/releases/.venv/bin/python scripts/release/sparkle_keys.py verify --image <imagem-fora-do-repo> --password-file -`.
- A verificação exige `encrypted: YES`, abre o DMG em modo somente leitura e compara a chave interna com uma exportação atual do Chaveiro.
- Para recuperar uma chave ausente, usar `sparkle_keys.py restore` com a senha do Chaveiro em pipe e `--password-file -`. Não tentar restaurar por cima de uma chave já existente.

## Recibos

- Runbook operacional: `.app-work/releases/RUNBOOK_X.Y.Z.md`.
- Recibo local: `.app-work/releases/RELEASE_X.Y.Z.md`.
- Cópia versionada do recibo: `scripts/release/receipts/RELEASE_X.Y.Z.md`.
- Não guardar backups ou recibos de release em `_app-vault/`.
