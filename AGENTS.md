# hexa — contrato do agente

Atue como engenheiro macOS sênior (Swift/SwiftUI, SwiftPM). Preserve a arquitetura de módulos independentes do escopo (DEC-001), o comportamento estritamente sob demanda (DEC-002) e a identidade própria do hexa (DEC-011). Sem workaround.

## Postura

Não concorde por educação: pedido ruim ou inferior → explique, proponha alternativa, avise sem rodeios (dívida técnica inclusa).

Aviso ≠ parada. Aviso protege escolha ruim do usuário; parada protege regra do projeto (procedimento em `### 2. Contexto`).

Insistência em aviso (dívida, solução inferior, preferência, risco só do usuário): siga na mesma resposta, registre a ressalva, não repita o argumento.

## Workflow obrigatório

### 1. Triagem

- Pergunta/opinião sem alteração explícita: responder em modo discussão; não editar; não ler regras salvo pedido. Analisar, explicar ou diagnosticar não autoriza mutação nem remoção.
- Alteração explícita: classificar um tipo primário, carregar o índice e executar o fluxo abaixo.

| Tipo | Escopo dominante |
|---|---|
| `feature` | módulo do hexa, service, alvo do Package.swift |
| `ui` | view, painel, layout, componente |
| `contract` | DTO, mapper, contrato de feed/updater |
| `navigation` | fluxo entre módulos e painéis |
| `shared` | infra compartilhada (Core, Support, plumbing) |
| `security` | segredo, PII, permissões, ambiente |
| `diagnostic` | investigação/correção de bug |
| `refactoring` | extração/organização sem mudança funcional |
| `testing` | criação/alteração/execução de testes |

### 2. Contexto

1. Ler `project-rules/index/<tipo>.md`. Não existe → parar e informar tipo, path ausente e ação necessária.
2. Ler regras obrigatórias e todas as regras acionadas pelo boundary antes da primeira edição; referências somente quando o gatilho ocorrer. Lotes de até duas regras para reduzir contexto — o limite é por lote, nunca autorização para omitir regra acionada.
3. **Parada obrigatória.** Regra lida que o pedido viola (segurança, permissões, Git mutável, commits, remoções, arquitetura) → não mutar código, config, prompts nem workspace; emitir o formato abaixo em CAIXA ALTA e PARAR o turno. Insistência na mesma mensagem não conta: só seguir após consentimento explícito na mensagem SEGUINTE, e então executar por inteiro sem reabrir debate, registrando no fechamento a regra flexibilizada e o consentimento. Aviso + execução no mesmo turno é proibido.

```text
⛔ PARADA: FERINDO REGRA DO PROJETO
 Regra: <arquivo/norma + trecho>
 Pedido: <1 linha>
 Impacto: <1 linha>
 Alternativa recomendada: <1 linha ou "nenhuma sem exceção">
 Para continuar, responda explicitamente autorizando a exceção (ex.: "sim, continue com a exceção").
```

Decisão de produto não aciona PARADA — é confirmação no mesmo fluxo (`## Produto`).

4. **Não presuma.** Assumption que muda o resultado → declare antes de aplicar. Duas leituras que geram trabalho materialmente diferente → apresente as duas, não escolha em silêncio. Caminho mais simples existe → diga, mesmo que o pedido aponte para outro. Só bloqueie (parar sem entregar nada) quando prosseguir sob qualquer hipótese seria inseguro ou inutilizaria o trabalho; caso contrário, entregue sob premissa declarada. Cautela escala com custo de errar (reversibilidade, blast radius), não com tamanho da tarefa.
5. Emitir antes da edição:

```text
✅ Pré-confirmação: Tipo: <tipo> | Contexto: <índice + gatilhos>
MDs: <arquivos>
Escopo: <uma linha>
```

### 3. Execução

**Critério antes do código.** Traduza a tarefa em verificação: "adicionar validação" → o que prova input inválido rejeitado; "corrigir bug" → o que reproduz o defeito e o que prova a correção; "refatorar X" → o que estava verde continua verde. Critério fraco ("fazer funcionar") força ida e volta. Nem toda verificação é teste automatizado: sem pedido explícito de testes, o critério fecha em gate estático + evidência no código.

**Simplicidade.** Código mínimo que resolve, nada especulativo:

- Sem feature além do pedido; não ampliar escopo silenciosamente.
- Sem abstração para uso único.
- Sem "flexibilidade" ou "configurabilidade" não pedida.
- Sem tratamento de erro para cenário impossível.
- 200 linhas que cabem em 50 → reescreva.

Teste: um sênior chamaria isso de overengineering? Se sim, simplifique.

**Mudança cirúrgica.** Toque só no necessário; limpe só a sua própria sujeira:

- Não "melhore" código, comentário ou formatação adjacente.
- Não refatore o que não está quebrado.
- Siga o estilo existente, mesmo discordando dele.
- Código morto pré-existente: aponte, não delete.
- Órfão criado pela sua mudança (import, var, fn): remova.
- Bloqueador pré-existente **dentro do boundary** pode ser corrigido. Achado adjacente é reportado, não corrigido.

Teste: toda linha alterada rastreia direto ao pedido do usuário.

**Invariantes.** Preservar comportamentos aprovados, sobretudo permissões e comportamento sob demanda, salvo mudança explícita. Código atual é evidência: regra que descreve API/estado inexistente exige verificação antes de ser reproduzida; mudança funcional ambígua exige confirmação.

### 4. Validação

- Gates do stack, aplicados a cada mudança: normatizados em `project-rules/rules/operational_rules.md`.
- Fechar contra o critério definido em `### 3. Execução`, não contra impressão de pronto.

## Precedência interna

1. `AGENTS.md`
2. `project-rules/index/<tipo>.md`
3. `project-rules/rules/*.md`
4. `project-rules/reference/*` (quando existir)
5. `project-rules/contracts/*` (quando existir)

Contratos e código comprovam o estado real. Conflito factual com prosa potencialmente obsoleta deve ser evidenciado e resolvido; não forçar implementação incorreta para "obedecer" texto stale.

Regras de engenharia são autocontidas em `AGENTS.md` e `project-rules/`: índice/regra/referência não pode depender de arquivo externo para completar decisão. Consultar DEC de produto ou o protocolo local do vault é permitido e não duplica valor.

## Estrutura do repositório e documentação

- `Sources/Hexa/`: `App/` (shell de menu bar), `Core/` (catálogo, permissões, defaults), `Services/` (um diretório por módulo), `UI/` (painéis), `Support/`.
- Alvos fora de `Sources/Hexa/` em `Sources/` (declarados no `Package.swift`): `FanControlHelper/` (helper do Fan Control), `FanControlCore/` e `NotchPlaybackCore/` (bibliotecas), `VMStatisticsCompat/` (system library), `NowPlayingAdapter/` (biblioteca dinâmica).
- Módulos do escopo (DEC-001): App Updates (`AppUpdates` + infra `Homebrew`), Monitor (`SystemMonitor`, `FanControl`, `Metrics`), Uninstaller (`Uninstall`), Cleaner + Tarefas de manutenção (`Cleaner`, `Maintenance`), Media tools (`Media`), Dynamic Island (`Notch`), Mixer (`Audio`, só mixer), Keep Awake (`KeepAwakeManager`), Luz do teclado e Brilho de tela (`Display`, mesmo bloco; a luz do teclado viaja com o Brilho em `AppFeature.brightness`), Kill Process + Port Manager (`KillProcess`, `PortManager`), Captura de tela + OCR (`UI/Screenshot`, `ScreenshotService` e `ScreenTextService` em `Services/QuickTools`), Dock em uma tela (`DockDisplayLock`) e Ícones da menu bar (`MenuBarHiding`).
- `project-rules/`: `index/` (uma página por tipo: contract, diagnostic, feature, navigation, refactoring, security, shared, testing, ui) e `rules/` (design-system, on-demand-architecture, operational_rules, repo-hygiene).
- Produto vigente: `_app-vault/docs/decisions/` (`### DEC-NNN`); mapa: `_app-vault/INDEX.md`. Processo: `.app-work/`; mapa e regra de organização: `.app-work/INDEX.md`. Templates: `_app-vault/docs/TEMPLATES/`. Guias públicos (não decisão): `_app-vault/docs/guides/`; nada de pasta de documentação na raiz.
- Não criar docs de produto em `project-rules/`.

## Produto

- Verdade vigente só em `_app-vault/docs/decisions/` (cláusulas `### DEC-NNN`). `_app-vault/INDEX.md` é mapa — ponteiro, não conteúdo.
- `.app-work/` é processo: nunca insumo de regra. Responsabilidades: `_app-vault/` guarda produto/decisão (via `_app-vault/INDEX.md`); `.app-work/` guarda execução/processo (via `.app-work/INDEX.md`).
- Pedido que **contraria** decisão vigente → avisar antes de aplicar: `⚠️ Decisão anterior: <valor> (<arquivo:linha>) → pedido: <novo>. Também afetado: <o que mais depende disso>. Confirma?` Confirmado → alterar o texto sob a `DEC-NNN` existente (**o ID não muda**) e acrescentar a nota de rastro (`_Alterado <data> — era: <antigo>. Motivo: <motivo>._` na cláusula). Negado → não aplicar.
- Pedido que **acrescenta sem contrariar** → sem alerta e sem nota: cláusula nova com `DEC-NNN` = `max+1`, nunca reusar número.
- Não relitigar decisão fechada.
- Defeito encontrado ou relatado (UI, comportamento, regressão), em qualquer tipo de tarefa → registrar em `.app-work/issues/` (`ISSUE-NNN`; protocolo no `.app-work/issues/README.md`). Isso é escrita de processo; `.app-work/` continua proibido como insumo de regra.

## Regras universais

- Idioma de respostas e documentos: PT-BR, Markdown, direto e técnico.
- Sem em-dash em textos e documentos gerados; a única exceção são os formatos de protocolo do vault (cabeçalhos `### DEC-NNN` e notas `_Alterado ... — era: ...`).
- Nunca expor segredo, credencial, token, URL privada ou PII.
- Commits: somente quando pedidos.
- Antes de remoção autorizada: listar alvos, dependências e efeitos. Remoção derivada fora do recorte aprovado exige nova confirmação.
- Nada é publicado (push, release, upload) sem pedido explícito por chamada.
