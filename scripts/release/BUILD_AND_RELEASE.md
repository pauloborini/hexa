# Contrato de build e release do Hexa

## Versão e alvos

- Fonte canônica da versão: `Sources/Hexa/Resources/ReleaseVersion.txt`.
- Sincronizar a versão com `CHANGELOG.md`, `release.json`, tag e Homebrew Cask.
- `release.json` é gerado dentro da pasta do artefato, não é um arquivo-fonte na raiz.
- O build inteiro avança a partir do último build público. Exemplo: v0.2.0 build 2, v0.3.0 build 3.
- A nova seção do `CHANGELOG.md` deve cobrir todos os idiomas de `AppLanguage.allCases`.
- Alvo público: app macOS arm64 em DMG assinado com Developer ID e notarizado pela Apple.
- Destino: GitHub Releases em `pauloborini/hexa`; o mesmo DMG serve para instalação manual e Sparkle.
- O asset `appcast.xml` usa o enclosure versionado do DMG e a assinatura EdDSA.
- `Casks/hexa.rb` aponta para o DMG da tag pública e é atualizado depois da publicação.

## Branches, revisão e tags

- O repositório usa Gitflow: `develop` é a integração e `main` recebe releases públicas.
- Integrar mudanças de funcionalidade em `develop`. Depois de fechar o escopo, cortar `release/vX.Y.Z` da ponta validada de `develop` e abrir a PR de release para `main`.
- Usar merge commit (`--no-ff`) para preservar o histórico de release.
- PRs de outros colaboradores precisam das aprovações configuradas no GitHub; não usar bypass administrativo para eles.
- PRs do proprietário podem usar bypass administrativo somente com autorização explícita. A autorização pode cobrir PRs equivalentes e sucessivas da mesma release quando o escopo estiver claro. Registrar cada PR afetada no runbook; nunca alterar a proteção global.
- Criar a tag anotada `vX.Y.Z` somente depois do PR para `main`, no SHA final validado.
- Depois da publicação, atualizar o Cask por PR para `main`. Em seguida, sincronizar `main` para `develop` por PR para levar versão, recibo e Cask.
- Depois da sincronização, conferir se as branches de feature, release, Cask e sync foram integradas e se há PRs que dependem delas. Com autorização do operador, remover apenas as branches já integradas e sem dependências. Manter `main`, `develop` e as tags de versão.
- O bootstrap v0.2.0 é a primeira release com updater; não criar release de teste pública para validar Sparkle.
- Rodar análise, testes e build local antes dos PRs. Gerar o pacote oficial no SHA validado de `main` depois da integração, pois `prepare_dmg.py` exige que a branch atual seja `main`.

## Smoke e evidências

- Executar o smoke numa única máquina macOS arm64 disponível ao mantenedor. Não exigir matriz por geração, classe mapeada ou chip fora do mapa.
- O registro de smoke valida R1, R2 e R3 com evidência para cada critério. Validar antes de criar o rascunho GitHub ou publicar; a PR de release para `main` pode ser integrada antes do smoke porque o pacote oficial só pode ser gerado em `main`.
- Não usar obrigações OBL de roadmaps externos como gate de publicação.
- Guardar o registro em `.app-work/smoke/X.Y.Z/RECORD.md`, fora do Git. O script `smoke_record.py` valida a versão, arm64, a atestação do operador e os caminhos de evidência.
- O smoke em uma geração não declara validação de recursos específicos de hardware em todas as gerações.

## Smoke local do updater

Executar R1, R2 e R3 depois de gerar e notarizar o DMG final e depois de gerar o appcast assinado desse mesmo DMG. A notarização recria o DMG, então um appcast gerado antes dela assina bytes antigos e precisa ser regenerado.

1. Identificar a instalação real, versão, build e processo ativo. Encerrar o Hexa normalmente. Antes da substituição, copiar o bundle atual para `.app-work/private/tmp/` e provar que o caminho é ignorado com `git check-ignore -v`.
2. Usar como baseline o DMG oficial da versão pública anterior. Um bundle criado por `./build.sh` pode ter `CFBundleVersion` com timestamp maior que o próximo build inteiro, fazendo Sparkle dizer que já está atualizado.
3. Registrar apenas os defaults selecionados pelo smoke e se `~/Library/Application Support/io.github.pauloborini.hexa` existe. Não exportar o domínio inteiro de preferências.
4. Para R2, copiar o appcast assinado e o DMG final para `.app-work/smoke/X.Y.Z/feed/`. Na cópia do appcast, trocar somente o URL do enclosure por um endereço loopback e manter `sparkle:edSignature` e os bytes do DMG inalterados. Servir a pasta somente em `127.0.0.1`, definir temporariamente `SUFeedURL` com `defaults write io.github.pauloborini.hexa SUFeedURL http://127.0.0.1:PORT/appcast.xml`, confirmar a atualização no diálogo Sparkle, instalar e reabrir, e comparar as preferências.
5. Para R1, restaurar o baseline oficial anterior, instalar manualmente o DMG novo por cópia do bundle completo e conferir versão, preferências, dados, assinatura, requisito designado e Gatekeeper.
6. Para R3, definir temporariamente `SUFeedURL` para um endereço loopback sem servidor. Confirmar a mensagem de falha, a permanência da versão atual e o botão de download manual.
7. Encerrar o servidor local, remover o override com `defaults delete io.github.pauloborini.hexa SUFeedURL`, confirmar que o valor sumiu e validar o registro com `scripts/release/smoke_record.py --check .app-work/smoke/X.Y.Z/RECORD.md`.

Não criar uma release pública de teste para R2. O appcast de produção fica inalterado; a cópia local é a única a receber o URL loopback.

## Gates

1. Ler o estado de `main`, `develop`, tags, proteções, PRs e branches `release/*` antes de qualquer mudança remota. Aguardar o fechamento de qualquer corte de release ativo antes de iniciar outro.
2. Rodar `scripts/release/check-secrets.sh` e as classes A e B do gate anti-vazamento antes do build. Classe B de Flutter não se aplica a este app Swift.
3. Rodar `swift build`, `swift test`, `./build.sh --release` e os testes dos scripts de release afetados.
4. Cortar `release/vX.Y.Z` da ponta validada de `develop`, preparar versão, changelog e recibos, validar gates locais e abrir PR para `main`. Consultar `gh pr checks` e reviews; se não houver checks, registrar isso no runbook sem marcar CI como aprovado. Bypass somente conforme a regra de branches acima.
5. Depois da integração, atualizar o checkout para `main` limpo no SHA do merge. Refazer o bundle Release e `build-release.sh` nesse SHA. Os binários de `build.json` precisam mostrar o mesmo SHA e `dirty: false`.
6. Gerar o DMG em `.app-work/releases/X.Y.Z/` com os produtos do mesmo SHA de `main`. Confirmar arm64, identidade Developer ID compatível com a instalação, assinatura e checksum.
7. Criar ou validar o backup EdDSA AES-256 fora do repositório antes de assinar o appcast. Conferir a evidência de recuperação da chave em um Chaveiro isolado. Notarizar o app e o DMG, validar os tickets e então gerar o appcast assinado a partir do DMG final.
8. Rodar a classe C no app e no DMG. Executar o smoke R1-R3 com o artefato final, criar evidência e validar `RECORD.md` antes do publisher.
9. Criar a tag anotada no SHA final de `main`, enviar a tag e publicar apenas pelo publisher do repositório. Confirmar tag, estado da release, lista de assets e o feed `releases/latest` público.
10. Depois da publicação, gerar e testar o Homebrew Cask, integrar o Cask e o recibo final por PR para `main`, e sincronizar `main` para `develop` por PR.

## Comandos de distribuição

O perfil local usa o ambiente Python em `.app-work/releases/.venv` para instalar os requisitos declarados:

```bash
python3 -m venv .app-work/releases/.venv
RELEASE_PYTHON=.app-work/releases/.venv/bin/python
"$RELEASE_PYTHON" -m pip install -r scripts/release/requirements.txt
./build.sh --release
PRODUCTS=.app-work/releases/release-products-X.Y.Z-SHA
scripts/release/build-release.sh "$PRODUCTS"
"$RELEASE_PYTHON" scripts/release/prepare_dmg.py --app build/hexa.app --products "$PRODUCTS" --build N --identity SHA1_FINGERPRINT --output .app-work/releases/X.Y.Z
"$RELEASE_PYTHON" scripts/release/notarize.py .app-work/releases/X.Y.Z --keychain-profile hexa-notary --identity SHA1_FINGERPRINT
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin "$RELEASE_PYTHON" scripts/release/feed_prepare.py .app-work/releases/X.Y.Z/hexa-X.Y.Z-arm64.dmg X.Y.Z --workdir .app-work/releases/X.Y.Z/feed
# Execute e valide o smoke R1-R3 antes de seguir com a tag e o publisher.
git tag -a vX.Y.Z -m "Release X.Y.Z"
git push origin vX.Y.Z
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin "$RELEASE_PYTHON" scripts/release/publish.py .app-work/releases/X.Y.Z --repo pauloborini/hexa --notes .app-work/releases/RELEASE_X.Y.Z.md --smoke-approved --smoke-record .app-work/smoke/X.Y.Z/RECORD.md --appcast .app-work/releases/X.Y.Z/feed/appcast.xml --publish
"$RELEASE_PYTHON" scripts/release/write_cask.py .app-work/releases/X.Y.Z
"$RELEASE_PYTHON" scripts/release/test_write_cask.py
```

`N` é o número de build inteiro da versão e `X.Y.Z` é a versão canônica. Antes de `publish.py`, confirmar que `main`, tag e `release.json` apontam para o mesmo SHA. O publisher cria o rascunho, anexa o feed e só remove o rascunho quando os dois assets exigidos estão presentes.
Substituir `SHA` pelo prefixo do commit validado em `main`, `N` pelo próximo build público e `SHA1_FINGERPRINT` pela impressão digital exata do certificado selecionado.

Use uma pasta de produtos única por versão e SHA, fora da pasta final do DMG, para não sobrescrever artefatos anteriores. Passe o mesmo caminho a `build-release.sh` e `prepare_dmg.py --products`. A pasta `.app-work/releases/X.Y.Z` precisa estar livre antes de `prepare_dmg.py`.

Se houver vários certificados Developer ID, passe em `SHA1_FINGERPRINT` a impressão digital do certificado que corresponde ao Team ID e ao requisito designado da instalação atual. O seletor atual aceita a impressão digital ou o nome completo do certificado; o Team ID sozinho não corresponde.

O appcast de produção deve ser gerado depois de `notarize.py`. O script stapla o app e recria o DMG, alterando os bytes e o checksum. Um feed gerado antes da notarização fica assinado para o arquivo antigo.

## Ignorados e artefatos locais

A raiz já ignora `.app-work/`, `.build/` e `build/`. Os recibos locais, smoke, appcast, DMGs, bundles de trabalho e backups temporários do app devem ficar nesses caminhos e ser verificados com `git check-ignore -v`. O backup privado da chave EdDSA fica fora do repositório. Não adicionar regras redundantes ao `.gitignore` para esses caminhos.

## Backup da chave EdDSA

- Gerar o backup com `scripts/release/sparkle_keys.py export --image <caminho-fora-do-repo>` e digitar uma senha no prompt. Para automação, a senha pode entrar por stdin com `--password-file -`. O comando recusa sobrescrever uma imagem existente.
- Se a senha aleatória já estiver no Chaveiro, passe-a por stdin com `--password-file -` tanto em `export` quanto em `verify`. O valor não deve aparecer em argumentos, arquivos temporários ou saída do terminal.
- O fluxo local armazena uma senha aleatória no Chaveiro do macOS, serviço `com.pauloborini.hexa.sparkle.backup`, conta `eddsa-encryption-passphrase`. A senha nunca vai para argumento de processo, terminal ou arquivo temporário.
- A senha da imagem é um item separado. Não alterar a ACL do item `Private key for signing Sparkle updates` para exportar ou verificar o backup.
- Manter o acesso da chave restrito às ferramentas Sparkle já autorizadas no Chaveiro. Não selecionar acesso por todos os aplicativos.
- Recuperar a senha para validação por pipe: `/usr/bin/security find-generic-password -s com.pauloborini.hexa.sparkle.backup -a eddsa-encryption-passphrase -w | SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin .app-work/releases/.venv/bin/python scripts/release/sparkle_keys.py verify --image <imagem-fora-do-repo> --password-file -`.
- A verificação exige `encrypted: YES`, abre o DMG em modo somente leitura e compara a chave interna com uma exportação atual do Chaveiro.
- Para comprovar a recuperação, restaurar a imagem em um Chaveiro isolado e vazio. Conferir a chave pública contra `scripts/release/sparkle_ed_public.txt`, assinar um arquivo de teste com a chave restaurada e validar a assinatura com a chave pública registrada. Guardar somente a evidência sem credenciais.
- Para recuperar uma chave ausente, usar `sparkle_keys.py restore` com a senha do Chaveiro em pipe e `--password-file -`. Não tentar restaurar por cima de uma chave já existente.

## Recibos

- Runbook operacional: `.app-work/releases/RUNBOOK_X.Y.Z.md`.
- Recibo local: `.app-work/releases/RELEASE_X.Y.Z.md`.
- Cópia versionada do recibo: `scripts/release/receipts/RELEASE_X.Y.Z.md`.
- O publisher usa o recibo local em `--notes`. Finalizá-lo com SHA, checksum, notarização e smoke antes da publicação.
- Finalizar a cópia versionada com os valores reais depois da publicação, junto com a atualização do Cask no PR pós-publicação. Essa alteração posterior não muda o SHA do DMG publicado.
- Não guardar backups ou recibos de release em `_app-vault/`.
