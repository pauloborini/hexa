# Versionamento

Affects: [app-updates, monitor, uninstaller, cleaner, maintenance-tasks, media-tools, dynamic-island, mixer, keep-awake, keyboard-light, screen-brightness, kill-process, port-manager, screen-capture]

### DEC-019 — Primeira versão pública beta

A primeira entrega pública do hexa usa `0.1.0` (versão estável, sem fase ou sufixo beta), com fonte única em `Sources/Hexa/Resources/ReleaseVersion.txt`. As funcionalidades nascem completas e estáveis diretamente na versão estável. A tag de publicação correspondente é `v0.1.0`. Definir a versão não autoriza criar tag, enviar artefatos ou publicar.
_Alterado 2026-10-11 — era: primeira versão com sufixo beta (0.1.0-beta) e pré-release. Motivo: operador determinou que cada versão deve ser tecnicamente estável e sem fase beta, com distribuição direta._

### DEC-043 — Smoke de release em uma máquina Apple Silicon
O smoke de cada release é executado em uma única máquina macOS arm64 disponível ao mantenedor. Não há matriz por geração de chip nem requisito de ensaio em chip fora do mapa. O registro cobre os fluxos definidos no contrato de release e não afirma que cada recurso específico de hardware foi exercitado em todas as gerações.

### DEC-045 — Canal e verificação das atualizações do próprio Hexa

O atualizador do próprio Hexa usa Sparkle 2 e lê um feed estável no GitHub Releases do repositório público, em `https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml`. O endereço do feed não muda entre versões; o pacote de cada versão fica no endereço versionado do DMG. Antes de substituir o app, a atualização é validada pela assinatura EdDSA do feed, além da assinatura Apple e da notarização: obter o pacote por HTTPS não basta.

A consulta ao feed ocorre somente quando o usuário pede a verificação (DEC-012). Verificação automática e download em segundo plano ficam desligados, e a consulta não envia perfil do sistema. O serviço recebe os metadados normais de uma conexão, sem analytics ou rastreamento pelo Hexa (DEC-005). Builds de desenvolvimento não consultam o feed público.

Decisão do operador entre 2026-11-10 e 2026-11-13.

### DEC-046 — Chave EdDSA de atualização fora do app e do repositório

A chave privada que assina o feed fica no Chaveiro local do mantenedor, separada do certificado Developer ID e do perfil de notarização. Ela nunca entra no app, no feed, no repositório ou em logs.

Existe um backup criptografado da chave, guardado fora do repositório e do Chaveiro principal. A recuperação do backup é comprovada em um Chaveiro isolado antes de o canal ser usado. A rotação da chave só acontece com procedimento que mantenha a continuidade de confiança das versões já instaladas. Se a chave e o backup forem perdidos juntos, o canal de atualização fica suspenso e os usuários são orientados ao DMG até a confiança ser restabelecida.

Decisão do operador entre 2026-11-10 e 2026-11-12.

### DEC-047 — Um DMG para instalação manual e atualização

O DMG assinado e notarizado de cada versão serve tanto para a instalação manual quanto para a atualização pelo Sparkle. Não há pacote de atualização separado por versão. Não há substituição silenciosa do formato: se a prova de compatibilidade com o Sparkle falhar, o atualizador fica suspenso e as releases manuais seguem como estão.

Falha de rede, de download ou de validação não remove nem substitui a versão instalada. O app atual continua utilizável, e a tela Sobre oferece o download da versão mais recente como recuperação manual. O DMG e o Homebrew Cask permanecem disponíveis para novas instalações.

Decisão do operador em 2026-11-12.

### DEC-048 — Transição da 0.1.0 para o atualizador

A versão 0.1.0 não contém atualizador. Quem a usa recebe a 0.2.0, primeira versão com atualizador, por instalação manual do DMG. A partir dela, as instalações com atualizador recebem as versões seguintes pelo próprio app, sempre com confirmação (DEC-012).

A transição é comprovada com instalação manual sobre uma 0.1.0 com preferências e dados locais preenchidos, conferindo também as permissões. A validação do Sparkle usa feed local em endereço de loopback, nunca uma release pública de teste.

Decisão do operador em 2026-11-16.
