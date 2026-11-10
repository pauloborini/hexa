# escopo-do-app

Affects: [app-updates, monitor, uninstaller, cleaner, maintenance-tasks, media-tools, dynamic-island, mixer, keep-awake, keyboard-light, screen-brightness, kill-process, port-manager, screen-capture, dock-display-lock, menu-bar-hiding]

### DEC-001 — Escopo fechado em módulos próprios

O hexa contém exatamente: App Updates, Monitor de sistema, Uninstaller, Cleaner + Tarefas de manutenção, Media tools, Dynamic Island, Mixer por app, Keep Awake, Luz do teclado, Brilho de tela, Kill Process + Port Manager, Captura de tela + OCR de tela (com atalhos globais), Dock em uma tela e Ícones da menu bar.
_Alterado 2026-11-08 — era: escopo sem Dock em uma tela nem Ícones da menu bar. Motivo: o operador confirmou os dois utilitários no escopo._
_Alterado 2026-10-22 — era: Cleaner, sem Tarefas de manutenção. Motivo: o operador criou as Tarefas de manutenção (flush DNS, purge de memória, snapshots locais, Launch Services, Spotlight e limpeza do Homebrew) e confirmou a inclusão no escopo, ao lado do Cleaner._
_Alterado 2026-10-06 — era: escopo fechado em 11 módulos. Motivo: o operador usa captura de tela e OCR (com atalhos) e pediu o módulo._

### DEC-002 — Tudo sob demanda

Painéis e scans só rodam quando abertos ou pedidos: sem polling em fundo, sem timers automáticos, sem alertas em fundo.

Exceção explícita para a Dynamic Island habilitada pelo usuário: as atividades compactas configuradas podem manter observadores, leituras e cadências próprias de acessórios, calendário, downloads, música/equalizador, inclusive os avisos dessas atividades. A infraestrutura de apresentação pode medir a barra e acompanhar Mission Control. A tela bloqueada só mantém atividades escolhidas para ela; tarefas iniciadas explicitamente, como timer, watch e conversão de arquivos, conservam seu ciclo de vida. Desativar a ilha encerra seus consumidores. A exceção não autoriza leitura geral de CPU, GPU, temperaturas, RPM ou rede com o painel fechado, nem scans de updates ou Cleaner em fundo.
_Alterado 2026-10-07 — era: proibição de polling, timers automáticos e alertas em fundo sem exceção para a ilha compacta. Motivo: o operador autorizou preservar as atividades compactas na preparação do smoke._
_Alterado 2026-10-08 — era: a infraestrutura de apresentação também agendava as visitas configuradas do mascote. Motivo: o Companheiro foi removido do app por decisão do operador._
_Alterado 2026-10-08 — era: as atividades compactas podiam manter observadores e avisos de agentes de IA. Motivo: o operador removeu o monitoramento de agentes de IA do app._

Exceção explícita para o FanControl autorizado pelo operador em 2026-10-07: sessão manual ou curva iniciada pelo usuário pode manter heartbeat e leituras necessárias à segurança e ao controle com o painel fechado. Recuperação de controle abandonado pode reativar o helper e repetir a devolução ao firmware até confirmação. Sem sessão ou recuperação, não há polling; telemetria de apresentação fica vinculada ao painel aberto ou à menu bar opt-in. Retomar após início/repouso exige opção explícita do usuário.
_Alterado 2026-10-07 — era: sem exceção nominada para o FanControl. Motivo: operador liberou o FanControl na preparação do smoke, incluindo sessão ativa e recuperação._

Exceção explícita para o Mixer habilitado: a observação de dispositivos e processos de áudio (CoreAudio, event-driven, sem polling) permanece ativa com painel fechado para re-aplicar volumes guardados. Enquanto um app com volume ajustado estiver tocando, uma conferência a cada 1,5 s verifica se o áudio dele travou (caso típico depois do sono) e o reconstrói; ela para quando todos os apps ajustados ficam em silêncio. Desativar o módulo encerra os observadores e a conferência.
_Alterado 2026-10-22 — era: observação event-driven, sem polling nem timer. Motivo: a auditoria fina (ISSUE-302) encontrou a conferência de áudio travado; o operador decidiu nomeá-la na exceção._
_Alterado 2026-10-09 — era: sem exceção nominada para o Mixer. Motivo: auditoria técnica apontou os listeners permanentes do AppVolumeMixer; operador registrou a isenção (ISSUE-060)._

Exceção explícita para o agendamento do Cleaner habilitado pelo operador: com frequência configurada explicitamente (padrão "off"), o CleanerScheduler mantém o timer do agendamento, executa scan e limpeza selecionada no máximo uma vez por dia e pode avisar em fundo, apenas com uma superfície do hexa visível. Sem agendamento configurado, nada roda.
_Alterado 2026-10-11 — era: sem exceção nominada para o agendamento do Cleaner. Motivo: a regra de engenharia (`project-rules/rules/on-demand-architecture.md`) já normatiza o scheduler com opt-in explícito; operador registrou a isenção._

### DEC-003 — Menu bar configurável

O usuário escolhe o que ocupa a menu bar: leituras de monitor (temperaturas e uso, limitadas ao escopo do DEC-001) ou o ícone do app. Leituras na menu bar são opt-in e a única amostragem geral de monitor em fundo permitida. As atividades compactas da Dynamic Island seguem a exceção delimitada em DEC-002. Ajuste do operador à proposta original de "ícone único".
_Alterado 2026-11-07 — era: limitadas ao escopo dos 12 módulos. Motivo: a contagem deixou de ser repetida em texto publicado e o escopo aponta para o DEC-001 (DEC-040)._
_Alterado 2026-10-07 — era: leituras na menu bar como única amostragem em fundo permitida. Motivo: reconciliar a exceção da ilha compacta autorizada em DEC-002, mantendo restrita a amostragem geral de monitor._
_Alterado 2026-10-06 — era: leituras limitadas ao escopo dos 11 módulos. Motivo: DEC-001 passou a 12 módulos (captura de tela + OCR) em 2026-10-06._

### DEC-004 — Homebrew por baixo

Atualização de apps e CLIs usa a CLI do brew (casks + fórmulas), com execução de processo limitada e ambiente controlado. Sem brew instalado, as seções de pacote simplesmente não aparecem.

### DEC-005 — Sem telemetria

Local-first, sem conta, sem análise e sem rastreamento.

### DEC-012 — Auto-update do próprio app

O Hexa oferece atualização do próprio app pela interface. A busca acontece somente quando o usuário solicita “Verificar atualizações”; se houver uma versão nova, o usuário confirma a instalação. Não há busca em segundo plano, instalação sem confirmação nem busca de versões beta. A distribuição por DMG e a substituição manual continuam disponíveis.
_Alterado 2026-10-11 — era: auto-update in-app consumindo feed de releases do repositório. Motivo: operador determinou simplificação do fluxo para distribuição direta e manual via DMG pelo usuário._
_Alterado 2026-11-10 — era: somente distribuição manual por DMG, sem auto-update in-app nem busca automatizada. Motivo: operador aprovou o updater in-app com busca iniciada pelo usuário e confirmação antes de instalar, mantendo o comportamento sob demanda._

### DEC-013 — Brilho sem XDR e sem dimming de tampa

O módulo de brilho cobre DDC onde suportado, dimming por software abaixo do mínimo e fallback por software. Fora do escopo: brilho acima do máximo (headroom HDR/XDR) e dimming da tela integrada com a tampa fechada. No Keep Awake com tampa fechada, a tela segue no brilho atual, sem escurecer.

### DEC-014 — Janela e tela unificadas por módulo

O hexa opera em janela única com sidebar unificada. Cada módulo reúne a utilização/operação e suas respectivas configurações na mesma tela de forma integrada: no cabeçalho do módulo, a alternância Operação/Ajustes troca a visão dentro da própria tela, sem janela nem sidebar separadas. A menu bar configurável (DEC-003) e a barra de atalhos do notch (DEC-008) são configuradas diretamente no contexto dos seus respectivos módulos ou nas opções gerais.
_Alterado 2026-10-14 — era: sem separação entre modos de funcionalidades e ajustes. Motivo: operador confirmou manter a alternância Operação/Ajustes no cabeçalho do módulo (plano semantica-segmentos-densidade-ui, ARCH-02)._
_Alterado 2026-10-10 — era: as configurações viviam em janela própria, com a infraestrutura compartilhada de settings e páginas dos 12 módulos. Motivo: unificação de janela e sidebar únicas com uso e configuração integrados na mesma tela por módulo._
_Alterado 2026-10-06 — era: páginas apenas dos 11 módulos. Motivo: DEC-001 passou a 12 módulos (captura de tela + OCR) em 2026-10-06._

### DEC-016 — Idiomas do app

O hexa se localiza em 15 idiomas. Textos novos, em qualquer módulo ou superfície, são localizados nos mesmos 15 idiomas.

### DEC-020 — Conversas antigas do Claude Code como categoria manual de limpeza

O Cleaner oferece as conversas antigas do Claude Code, em `~/.claude/projects`, como categoria de limpeza manual. Cada conversa é o par `<projeto>/<uuid>.jsonl` mais a pasta `<projeto>/<uuid>/`, movidos juntos para a Lixeira. A idade é a última atividade do par. O padrão é 30 dias, com as opções de 7, 14, 30, 60 e 90 dias, ou desligado com zero. Os itens nascem desmarcados, nunca entram no passe automático do agendamento e não são pré-selecionados. Conversas referenciadas pelo app desktop do Claude ficam de fora, para não quebrar a sessão dele. A memória do projeto e qualquer outro arquivo ficam fora da categoria.

### DEC-021 — Piso de segurança e sem corte térmico no FanControl

No modo manual, o FanControl mantém um piso de 1200 RPM enquanto alguma leitura térmica válida passar de 50°C, enquanto a amostra não tiver leitura válida ou enquanto o Mac expuser sensores dos núcleos da CPU e a amostra não tiver nenhuma leitura de CPU. O piso fica limitado ao mínimo e ao máximo de RPM informados pelo SMC para cada ventoinha, e só eleva o alvo. Curva e demais modos não mudam.

_Alterado 2026-10-15 — era: No modo manual, o FanControl mantém um piso de 1200 RPM enquanto alguma leitura térmica válida passar de 50°C ou enquanto a amostra não tiver leitura válida. Motivo: em Mac com sensores dos núcleos da CPU, uma amostra sem nenhuma leitura de CPU não ativava o piso. O piso passa a cobrir esse caso._

Com sessão manual ativa, a temperatura é lida em cada tick do watchdog, dentro da exceção do FanControl em DEC-002. Três ticks seguidos sem leitura térmica válida devolvem o controle ao automático, com o motivo de temperatura indisponível.

Com sessão manual ativa, o estado térmico do sistema é avaliado no mesmo tick do watchdog. A partir de `serious` (sério ou crítico), o controle volta ao firmware com motivo térmico visível no painel do Fan Control e fica com o firmware até o usuário reativar o modo manual; não há retorno automático quando o estado normaliza. Não há corte por graus.

_Alterado 2026-10-28 — era: Não há corte térmico por graus nem pelo estado térmico do sistema (`serious` ou `critical`). A proteção contra superaquecimento que resta é a do próprio chip, não medida nesta decisão. Motivo: reativação do corte térmico por estado térmico do sistema (ROADMAP D18, Q-RM-10)._

Decisão do operador em 2026-10-15.

### DEC-022 — Sessão do FanControl exige aviso de sono armado

O FanControl só inicia uma sessão de resfriamento se o aviso de sono do sistema estiver armado. Se o registro falhar, a sessão não começa e nenhuma ventoinha é alterada. Quando há sessão ativa ou recuperação pendente, o aviso de sono devolve as ventoinhas ao automático antes da confirmação ao sistema. O registro existe enquanto houver sessão ou recuperação pendente e é desfeito quando o helper fica ocioso.

Decisão do operador em 2026-10-15.

### DEC-024 — Prévia de captura de tela é opt-in

Ao realizar uma captura de tela, a exibição de prévia pós-captura (seja na Dynamic Island/notch ou no flutuante na tela) é opt-in e vem desativada por padrão. O usuário pode ativar a prévia nos ajustes de Captura de tela e escolher o destino da apresentação: na Dynamic Island (notch) ou na tela (painel flutuante). Com a prévia desativada, a captura é salva ou copiada diretamente conforme a ação configurada, sem abrir janelas flutuantes nem ocupar a Dynamic Island.

Decisão do operador em 2026-10-18.

### DEC-027 — Só Apple Silicon

O hexa roda só em Macs com Apple Silicon. A distribuição gera DMG arm64, sem fatia Intel. Leituras e controles que dependem de hardware (temperaturas, DDC, FanControl) não precisam de caminho para Intel.

Decisão do operador em 2026-10-22.

### DEC-030 — Captura salva por padrão

Numa instalação nova, a ação padrão depois de uma captura é salvar o arquivo na pasta de capturas. Salvar e copiar, copiar e abrir no editor são escolhas do usuário (opt-in) nos ajustes de Captura. Complementa DEC-024: com a prévia desligada, a captura nunca se perde.

Decisão do operador em 2026-10-22.

### DEC-031 — Desinstalar o hexa pelo app

Avançado, no grupo Preferências da barra lateral, oferece "Desinstalar o Hexa completamente", com confirmação. A ação devolve as ventoinhas ao sistema, remove o helper do FanControl, o item de login e a regra `sudoers` da tampa fechada, devolve os atalhos do macOS assumidos, apaga ajustes e caches do hexa e move o app para a Lixeira.

_Alterado 2026-11-09 — era: Ajustes > Avançado oferece "Desinstalar o hexa". Motivo: alinhar ao caminho e ao rótulo reais da janela única._

Decisão do operador em 2026-10-22.

### DEC-033 — Desligar a Captura com anotações abertas

Desinstalar a Captura de tela no hub com um editor aberto e anotações não exportadas mostra o mesmo aviso de descarte do botão de fechar e do encerramento do app. "Cancelar" mantém a Captura instalada e o editor aberto.

Decisão do operador em 2026-10-22.

### DEC-034 — Limite de bateria do Keep Awake ajustável

Os ajustes do Keep Awake oferecem o limite de bateria que encerra a sessão e bloqueia as automações: Nunca, 5%, 10% (padrão) e 20%.

Decisão do operador em 2026-10-22.

### DEC-035 — Liberar DNS completo com senha

"Liberar DNS" limpa o cache do Directory Services e reinicia o cache do `mDNSResponder`. A tarefa pede a senha de administrador pelo próprio macOS, só quando o usuário a executa.

Decisão do operador em 2026-10-22.

### DEC-037 — Primeira execução com tela de boas-vindas própria

Na primeira execução, o hexa mostra uma tela de boas-vindas própria, uma vez só: apresenta o app e os módulos do escopo (DEC-001), agrupados nas linhas que a tela mostra, com o estado real de instalação, guia a concessão das permissões que os módulos marcados exigem, e termina com o app na menu bar. Desligar um módulo na tela tem o mesmo efeito de desligá-lo na central de Ajustes: o módulo é desinstalado do app. Recusar uma permissão não impede a conclusão. A tela é uma superfície de primeira execução, com janela própria, e não altera a janela única com sidebar unificada dos módulos (DEC-014). Ela segue o design system e a paleta próprios (DEC-017), nos 15 idiomas da base (DEC-016), e não traz bloco de novidades: as notas da versão ficam na tela Sobre e no aviso posterior à atualização.
_Alterado 2026-11-07 — era: apresenta o app e os 12 módulos do escopo (DEC-001) com o estado real de instalação. Motivo: a tela agrupa os módulos em linhas e não repete a contagem; o escopo segue no DEC-001 (DEC-040)._

Decisão do operador em 2026-10-28 (Q-RM-40 a Q-RM-47, slice M13).

### DEC-038 — Refazer o onboarding pela tela Sobre

A tela Sobre tem um botão que refaz o onboarding. A reexecução abre o mesmo roteiro com o estado real de instalação de cada módulo: o que já ficou desligado continua desligado e o que foi concedido continua concedido. Não existe onboarding automático, por evento ou por versão.

Decisão do operador em 2026-10-28 (Q-RM-48, slice M13).

### DEC-040 — A contagem de módulos não se repete

O escopo do DEC-001 é a única fonte da quantidade de módulos. Texto do app, documentação, site e material de divulgação nomeiam os módulos ou apontam para o DEC-001, sem repetir o número: acrescentar ou remover um módulo atualiza o DEC-001, não contagens espalhadas. A quantidade de linhas de uma tela também não é dado de produto; a tela descreve o que mostra.

Decisão do operador em 2026-11-07.

### DEC-041 — Fronteira dos ícones ocultos na menu bar

Com "Ícones da menu bar" ligado, o chevron fica visível e acionável como fronteira: itens de outros apps à esquerda pertencem à seção oculta; itens à direita ficam sempre visíveis. Os itens do próprio macOS (Central de Controle, Tocando Agora, relógio e demais itens do sistema) ficam sempre visíveis, de qualquer lado do chevron. O módulo inicia recolhido. Um clique no chevron revela temporariamente os itens ocultos; outro clique recolhe imediatamente. O prazo de recolhimento é configurável como Instantâneo, 5 segundos (padrão) ou 10 segundos. Instantâneo recolhe ao terminar a interação: clique fora da menu bar ou Escape. Desligar o módulo libera todos os itens. Itens cuja identidade ou posição não puder ser lida permanecem visíveis para evitar ocultar algo que o usuário não classificou.

_Alterado 2026-11-09 — era: seção sempre oculta separada, com prazo temporário genérico. Motivo: remover “Sempre invisível” da v1, preservar seus itens na seção oculta comum e oferecer prazos de recolhimento explícitos._

_Alterado 2026-11-09 — era: só os itens à direita do chevron ficavam sempre visíveis, sem exceção para os itens do macOS. Motivo: a restrição do macOS 27 escondia o Tocando Agora da Central de Controle junto com os ícones ocultos (ISSUE-936)._

Decisão do operador em 2026-11-08.
