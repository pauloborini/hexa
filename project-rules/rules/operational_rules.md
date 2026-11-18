# operational_rules

Gates de validação do hexa (Swift/SwiftUI, SwiftPM, macOS 14+). Aplicados a cada mudança, antes de considerar o trabalho pronto.

## Gates

1. `swift build` na raiz: o gate fecha com TODOS os alvos do `Package.swift` compilando (app `Hexa` + helpers `FanControlHelper`, `NowPlayingAdapter` + system libraries).
2. `swift test`: obrigatório quando o alvo alterado (ou tocado pela mudança) tiver testes em `Tests/`; sem testes no recorte, o gate é dispensado.
3. Build de distribuição: `./build.sh` (script na raiz, slice M8); o `.app` gerado em `build/hexa.app` fica fora do Git (`build/` já ignorado).
4. `git diff HEAD --check`: sem conflito de whitespace/marcadores antes de qualquer commit.

## Critério

Fechar contra o critério definido na tarefa (o que prova a mudança), não contra impressão de pronto. Nem toda verificação é teste automatizado: sem pedido explícito de testes, o critério fecha em gate estático + evidência no código.

## Gate de arquitetura

Além dos gates de build: nenhuma mudança introduz polling em fundo, timer automático ou amostragem fora da visibilidade do painel sem estar nas exceções nominadas de `on-demand-architecture.md`; órfão criado pela mudança (import, alvo, recurso) é removido na mesma mudança.

## Atualização local do app instalado

Quando o objetivo inclui instalar um build local sobre uma cópia já instalada:

1. Identificar o caminho real da cópia usada e confirmar se há processo ativo e de onde ele executa. Não presumir que `build/hexa.app` é a instalação em uso.
2. Conferir a identidade de assinatura e o designated requirement do bundle instalado. Construir o novo bundle com a mesma identidade, bundle ID e requisito de código. No macOS 27, `MenuBarHiding` exige Developer ID; o `build.sh` pode selecionar Apple Development por padrão, então use `HEXA_CODESIGN_IDENTITY` para forçar a identidade instalada quando necessário.
3. Antes da substituição, guardar uma cópia recuperável do bundle em `.app-work/private/tmp/` e provar que o caminho está ignorado por Git. Preferências do usuário ficam fora do bundle e não devem ser apagadas.
4. Encerrar o app normalmente. Não substituir um bundle que ainda esteja em execução nem forçar o encerramento se houver operação ou documento com risco de perda.
5. Substituir o bundle instalado por inteiro no mesmo caminho, sem manter uma segunda instância e sem copiar por cima de modo que mescle arquivos antigos com novos. Não editar nem remover registros de privacidade e segurança do macOS como parte da instalação.
6. Antes de reabrir, verificar a assinatura e comparar o designated requirement com o bundle anterior. Depois de abrir, confirmar novamente o caminho e a versão do processo ativo e conferir o estado das permissões e do recurso testado.

Se a identidade ou o requisito de código mudar, não trate a instalação como atualização equivalente: o macOS pode exigir nova concessão de Acessibilidade ou de outra permissão. Preserve o backup e pare para explicar a diferença antes de pedir qualquer alteração em Ajustes do Sistema.
