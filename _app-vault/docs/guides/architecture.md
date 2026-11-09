# Arquitetura do Hexa

Este documento descreve as decisões arquiteturais, o ciclo de vida dos módulos e as garantias de privacidade e desempenho do **Hexa**.

O Hexa é um utilitário nativo para a barra de menus do macOS, projetado exclusivamente para a plataforma Apple Silicon e distribuído sob a licença GPL-3.0-or-later.

---

## 1. Princípios Fundamentais

A engenharia do Hexa é regida por quatro princípios invariantes:

### 100% Sob Demanda (Zero Polling) - DEC-002
Ao contrário dos utilitários tradicionais de monitoramento e manutenção de sistema, o Hexa não mantém rotinas periódicas de leitura em segundo plano, nem executa temporizadores ou varreduras ocultas:
- **Amostragem vinculada à visibilidade:** Módulos de monitoramento (CPU, GPU, memória, disco, rede, sensores de bateria e ventiladores) só coletam métricas no instante em que o painel correspondente está aberto na tela. Quando a janela ou painel é fechado, observadores e timers são imediatamente cancelados.
- **Sem cache fantasma:** Não há acúmulo de histórico de telemetria em segundo plano "para abrir mais rápido". A primeira leitura ao abrir o painel é fria e instantânea.
- **Degradação graciosa:** Se uma ferramenta externa não estiver instalada (por exemplo, a CLI do Homebrew), as seções correspondentes deixam de ser renderizadas silenciosamente, sem tentativas cíclicas de reconexão ou alertas permanentes (DEC-004).

### 100% Local-First e Privacidade Absoluta - DEC-005
O Hexa não inclui nenhum código de rastreamento, análise de telemetria, identificadores de usuário ou dependência de servidores em nuvem:
- Nenhum dado de hardware, arquivos inspecionados ou processos monitorados sai da máquina.
- Não há cadastro de conta, chaves de API remotas nem coleta de métricas de uso anônimas.
- Toda a lógica de verificação de atualizações de aplicativos e manipulação de arquivos reside localmente no sistema operacional.

### Exclusividade Apple Silicon - DEC-027
O Hexa foi desenhado especificamente para a arquitetura ARM dos Macs modernos:
- Binário compilado unicamente para `arm64`, sem fatias legadas de arquitetura Intel x86_64.
- Uso direto dos sensores térmicos do Apple Silicon, controle do SMC específico das ventoinhas e aceleração de hardware via frameworks da Apple (Accelerate, Vision).

### Janela Única com Sidebar Unificada - DEC-014 e DEC-018
A navegação do Hexa elimina janelas dispersas e configurações descentralizadas:
- Todas as operações completas e ajustes de cada módulo residem em uma janela principal unificada com barra lateral (sidebar).
- **Alternância Operação / Ajustes no cabeçalho:** Cada tela de módulo possui um seletor no cabeçalho que permite alternar imediatamente entre a visão operacional da ferramenta e as preferências de configuração do módulo, sem necessidade de janelas de preferências secundárias.
- O painel suspenso da barra de menus (menu bar) serve como superfície de leitura rápida e gatilho de ferramentas sob demanda.

---

## 2. Ciclo de Vida dos Módulos (On-Demand Lifecycle)

Cada módulo do Hexa é implementado em `Sources/Hexa/Services/` e expõe um ciclo de vida controlado centralmente pelo catálogo de recursos: o enum `AppFeature` (`Sources/Hexa/Core/FeatureCatalog.swift`) define a disponibilidade de cada módulo, persistida em chaves de `DefaultsKey` (`Sources/Hexa/Core/Defaults.swift`), e o `FeatureRuntime` (`Sources/Hexa/App/FeatureRuntime.swift`) só instancia o serviço de um módulo disponível. Módulo desligado no hub de Ajustes desmonta seu serviço e não é carregado no próximo início.

```
┌────────────────────────────────────────────────────────┐
│                     Menu Bar / UI                      │
└───────────────────────────┬────────────────────────────┘
                            │ Painel Aberto / Ação do Usuário
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Módulo de Serviço                    │
│  - Inicia observadores e amostragem                    │
│  - Executa tarefas pontuais (scan, conversão, OCR)     │
└───────────────────────────┬────────────────────────────┘
                            │ Painel Fechado / Conclusão
                            ▼
┌────────────────────────────────────────────────────────┐
│             Descarregamento de Recursos                │
│  - Cancela timers e leitores de hardware               │
│  - Libera memória e encerra processos de apoio         │
└────────────────────────────────────────────────────────┘
```

### Exceções Formalmente Delimitadas (DEC-002)

Para garantir funcionalidade contínua quando explicitamente solicitado pelo usuário, foram definidas exceções estritas à proibição de rotinas em segundo plano:

1. **Leituras na Barra de Menus (DEC-003):** Se o usuário ativar leituras na barra de menus (como uso de CPU ou temperatura), o Hexa mantém uma amostragem leve em cadência baixa (intervalo em segundos, nunca milissegundos). Esta é a única amostragem contínua de monitoramento permitida e ela é desativada imediatamente se a opção for desligada. O padrão de fábrica exibe apenas o ícone do Hexa.
2. **Atividades Compactas da Dynamic Island:** Quando a Dynamic Island está ligada, as atividades compactas configuradas pelo usuário (acessórios, calendário, downloads, música/equalizador) podem manter observadores, leituras e avisos próprios para atualizar o entalhe físico. Tarefas iniciadas explicitamente, como timer, watch e conversão de arquivos, conservam seu ciclo de vida. Desativar a ilha cancela todos os seus observadores e timers.
3. **Sessão Ativa do FanControl:** Se o usuário iniciar manualmente uma curva de ventoinha ou modo de resfriamento, o helper mantém heartbeat, watchdog e as leituras necessárias para garantir a integridade térmica do computador enquanto a sessão estiver em vigor. Após uma sessão abandonada, a recuperação pode reativar o helper até confirmar a devolução ao firmware. Sem sessão nem recuperação, não há polling.
4. **Mixer de Volume por App:** Utiliza observadores baseados em eventos do CoreAudio (sem polling). Quando há um app reproduzindo áudio e com volume personalizado, uma verificação leve a cada 1,5 segundos monitora se o canal de áudio travou após suspensão do Mac. Ela é interrompida assim que os apps entram em silêncio.
5. **Agendamento de Limpeza do Cleaner:** Apenas se o usuário configurar expressamente uma frequência (diária ou semanal) no agendador (`CleanerScheduler`), o scan e a limpeza dos grupos seguros rodam no máximo uma vez por dia, somente com uma superfície do Hexa visível, com aviso opcional ao final. Sem agendamento explícito (o padrão é desativado), nenhum timer ou observador existe.

---

## 3. Arquitetura de Controle Térmico (FanControl e SMC)

O controle de resfriamento do Hexa foi estruturado com arquitetura de alta segurança para evitar sobreaquecimento ou falhas de controle do hardware:

```
┌───────────────────────┐         XPC autenticado         ┌────────────────────────────┐
│       Hexa.app        │ ◄─────────────────────────────► │      FanControlHelper      │
│ (Interface de Usuário)│                                 │ (Executável Privilegiado)  │
└───────────────────────┘                                 └──────────────┬─────────────┘
                                                                         │ Chamadas SMC
                                                                         ▼
                                                          ┌────────────────────────────┐
                                                          │    Apple Silicon SMC       │
                                                          │  (Ventoinhas e Sensores)   │
                                                          └────────────────────────────┘
```

### Divisão de Privilégios via Helper Dedicado
O aplicativo principal `Hexa` não executa operações do SMC diretamente como administrador. Ele interage através de um executável independente (`FanControlHelper`), localizado em `Sources/FanControlHelper/`, registrado como daemon do sistema via `SMAppService` e executado como root. A comunicação usa um mach service XPC privilegiado (`NSXPCConnection` com o protocolo `FanControlXPCProtocol`, definido em `Sources/FanControlCore/`), autenticado nos dois sentidos por requisito de assinatura de código: o app exige do helper, e o helper exige do app, assinatura Apple com o mesmo Team ID e o identificador esperado. Binário sem Team ID é rejeitado.

### Piso de Segurança de 1200 RPM (DEC-021)
No modo manual do FanControl:
- Enquanto alguma leitura térmica válida ultrapassar **50°C**, a amostra de sensores não contiver leitura válida de temperatura, ou o Mac expuser sensores dos núcleos da CPU e a amostra não tiver nenhuma leitura de CPU, o Hexa impõe um piso mínimo de **1200 RPM** às ventoinhas.
- Esse piso fica limitado ao mínimo e ao máximo de RPM informados pelo SMC para cada ventoinha e só eleva o alvo: tem precedência sobre comandos manuais de rotação mais baixa. Curva e demais modos não mudam.
- Se o watchdog passar três ticks seguidos sem leitura térmica válida, o controle é devolvido imediatamente ao firmware nativo da Apple.

### Devolução ao Firmware em Estados Térmicos Críticos
Durante uma sessão manual de resfriamento, o estado térmico global reportado pelo macOS é avaliado a cada tick do watchdog (DEC-021). Se o sistema entrar em estado `serious` ou `critical`, o controle das ventoinhas é revertido de imediato para a gestão automática da Apple, com motivo térmico visível no painel. O controle permanece com o firmware até o usuário reativar o modo manual; não há retorno automático nem corte por graus.

### Proteção Obrigatória de Suspensão do Sistema (DEC-022)
Uma sessão de controle de ventoinha só pode ser iniciada se o helper registrar com sucesso o aviso de sono do sistema (`IORegisterForSystemPower`, do IOKit); se o registro falhar, a sessão não começa e nenhuma ventoinha é alterada. Quando o computador entra em repouso (sleep) com sessão ativa ou recuperação pendente, as ventoinhas são devolvidas ao modo automático antes da confirmação ao sistema, evitando que o Mac durma com rotações fixas inadequadas. O registro é desfeito quando o helper fica ocioso.

---

## 4. Design System e Identidade Visual

O Hexa possui identidade visual própria e autoral (DEC-011 e DEC-017), sem reaproveitar esquemas genéricos de outros produtos:

- **Conceito da Marca:** Conceito A ("Segmento Aberto"), composto por um hexágono segmentado com um segmento solto e núcleo em tom de latão metálico.
- **Tipografia:** Combinação harmoniosa de *Instrument Serif* (títulos e detalhes clássicos), *Manrope* (interface limpa e legível) e *IBM Plex Mono* (métricas numéricas e dados de terminal).
- **Paleta de Cores Semântica:** Baseada na paleta tinta/bone/latão, com dois temas (escuro como palco padrão do design e claro) e pares de contraste medidos contra WCAG 2.1 AA. O latão é a cor da marca (logo e wordmark); os papéis de accent da interface usam um accent neutro da família taupe. Estados e dados usam canais neutros, texto e forma; o laranja é reservado ao indicador de sessão ativa do Keep Awake (DEC-018). A aparência do app segue o sistema por padrão e pode ser fixada em clara ou escura.
- **Tokens e Componentes:** As views consomem tokens semânticos de `HexaTheme` (`Sources/Hexa/Support/HexaTheme.swift`) e componentes compartilhados em `Sources/Hexa/UI/Components/` (como `HexaCard`); o registro canônico de valores fica em `_app-vault/specs/design-system.md`.
- **Ícones de Interface:** Conjunto consistente de ícones vetoriais da família *Lucide*, embutidos diretamente no aplicativo.

---

## 5. Estrutura de Código no Repositório

```
Sources/
├── Hexa/                      # Executável principal do aplicativo
│   ├── App/                   # Ponto de entrada, ciclo de vida do app e menu bar
│   ├── Core/                  # Catálogo de recursos, defaults, gerenciamento de permissões e l10n
│   ├── Services/              # Implementação lógica dos módulos
│   ├── Support/               # Tema (HexaTheme), probes de depuração e utilitários
│   ├── UI/                    # Telas em SwiftUI, painéis flutuantes e componentes
│   └── Resources/             # Fontes OFL, ícones Lucide e marca
├── FanControlCore/            # Biblioteca compartilhada: cliente SMC, política de segurança e protocolo XPC
├── FanControlHelper/          # Executável privilegiado (root) que fala com o SMC
├── NotchPlaybackCore/         # Biblioteca de abstração para controle de mídia da Dynamic Island
├── NowPlayingAdapter/         # Biblioteca dinâmica (.dylib) que lê a sessão Now Playing do sistema
└── VMStatisticsCompat/        # Módulo de sistema (header C) para estatísticas de memória do Mach
```
