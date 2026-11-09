# on-demand-architecture

Norma de implementação do comportamento sob demanda do hexa. Produto vigente: DEC-002 (tudo sob demanda) e DEC-003 (menu bar configurável), em `_app-vault/docs/decisions/escopo-do-app.md` — esta regra normatiza o COMO, sem duplicar o valor das decisões.

## Amostragem vinculada à visibilidade

- `SystemMonitor`, `Metrics` e qualquer leitura de hardware (SMC, RPM, rede) amostram SOMENTE enquanto o painel correspondente está aberto. Fechou o painel, para a amostragem (cancelar observers e timers).
- Não criar cache de métricas em fundo "para abrir mais rápido". A primeira leitura do painel é fria mesmo.

## Proibições em fundo

- Proibido: polling periódico, timers automáticos, scans agendados e daemons de alerta fora das exceções nominadas abaixo.
- Proibido: verificação de updates em fundo. O scan de updates roda só quando o painel abre, o operador pede refresh ou o app é ativado, com cadência limitada (DEC-012).
- Scheduler do Cleaner (`CleanerScheduler`) só executa quando o operador configura um agendamento explicitamente; sem agendamento configurado, nada roda.

## Exceção de monitor: menu bar configurável

- A leitura impressa na menu bar (DEC-003) é opt-in e é a única amostragem geral de monitor em fundo permitida no app.
- Quando ativada, cadência baixa (mínimo viável, alvo de segundos, não de milissegundos), conteúdo limitado ao escopo do DEC-001, e ela desliga sozinha se a feature for desativada.
- Padrão do app: ícone do app na menu bar, sem leituras impressas.

## Exceção delimitada: atividades compactas da Dynamic Island

- Com a ilha habilitada e a atividade configurada, são permitidos os consumidores de acessórios, calendário, downloads e música/equalizador, com suas cadências e avisos próprios (DEC-002).
- Medições de espaço na barra e Mission Control pertencem à apresentação da ilha. Nada disso autoriza scans de outros módulos.
- Desativar a ilha cancela observadores, timers e leitores. Suspensão de sessão/tela desmonta a apresentação e seus consumidores; a tela bloqueada retoma somente as atividades escolhidas para ela.
- Timer, watch e trabalho de arquivos iniciados pelo usuário conservam o ciclo de vida da tarefa solicitada.
- A exceção não mantém leituras gerais de CPU/GPU, temperatura, RPM ou rede fora da visibilidade dos painéis. A barra de atalhos continua sem polling próprio.

## Exceção delimitada: FanControl

- Sessão manual/curva iniciada pelo usuário mantém heartbeat, watchdog e leituras necessárias ao controle e à segurança fora do painel (DEC-002).
- Telemetria de apresentação só é solicitada com o painel aberto; leituras opt-in da menu bar continuam sob DEC-003.
- Marcador de recuperação mantém o helper recuperável após morte do processo até confirmar controle automático. Retries não podem limpar o marcador antes dessa confirmação.
- Sem sessão nem recuperação, cancelar timers/conexão; o helper encerra ocioso. Resume exige a preferência explícita do usuário.

## Degradação sem dependências

- Sem `brew` no PATH, as seções de pacote/CLI do App Updates nem aparecem (DEC-004): sem erro, sem aviso permanente, sem retry em fundo.
- Features de hardware (Fan Control, temperaturas) informam "não suportado" no painel quando o hardware não expõe o sensor; nunca adivinham valor.
