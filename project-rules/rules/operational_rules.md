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
