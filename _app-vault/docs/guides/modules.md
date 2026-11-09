# Módulos do Hexa

O Hexa reúne os módulos especializados do escopo (DEC-001) em uma única aplicação nativa para macOS, eliminando a necessidade de múltiplos utilitários dispersos.

Cada módulo foi construído sob o princípio de operação sob demanda (DEC-002): painéis e varreduras só rodam quando abertos ou pedidos, sem polling em fundo. As únicas exceções são as nominadas no próprio DEC-002 (atividades da Dynamic Island habilitada, sessão ativa do Fan Control, observadores do Mixer e agendamento do Cleaner configurado pelo usuário) e as leituras opt-in na menu bar (DEC-003).

Os módulos são instalados e desinstalados em **Recursos > Catálogo**; a finalidade de cada permissão e os módulos que a usam ficam em **Recursos > Permissões**. Kill Process, Port Manager, Fan Control, Dock em uma tela e Ícones da menu bar vêm desinstalados por padrão.

---

## 1. App Updates (Atualizações de Aplicativos)

O módulo **App Updates** unifica a verificação e instalação de atualizações para todos os softwares instalados no Mac:

- **Mac App Store:** Comparação de versões pelo catálogo da App Store; a instalação é entregue ao aplicativo App Store, que conclui a atualização.
- **Homebrew Casks e Fórmulas:** Atualização de aplicativos gráficos e ferramentas de terminal gerenciadas pelo Homebrew.
- **Feeds Sparkle e Desenvolvedor:** Identificação de novas versões distribuídas diretamente pelos mantenedores de software via feeds XML/RSS, com o catálogo público de casks do Homebrew como alternativa para apps instalados fora dele. A atualização é feita pelo atualizador do próprio app, que o Hexa abre.
- **Comportamento Sob Demanda:** Nenhuma verificação automática roda em segundo plano. O escaneamento só ocorre quando o usuário abre a interface do módulo ou clica em verificar.
- **Degradação sem Homebrew (DEC-004):** Se o Homebrew não estiver instalado no sistema, as seções de pacotes simplesmente não aparecem na lista, sem mensagens de erro recorrentes; só a fonte Homebrew, nos Ajustes do módulo, explica por que não encontra nada.

---

## 2. Monitor de Sistema

Um painel completo de telemetria de hardware com amostragem fria, acionado estritamente enquanto a janela está visível:

- **CPU:** Percentual de uso total, histórico de carga e temperaturas de sensores térmicos do Apple Silicon.
- **GPU:** Utilização dos núcleos gráficos e temperatura dedicada da GPU.
- **Memória RAM:** Memória usada e usada por apps, memória comprimida, arquivos em cache, índice de pressão de memória do macOS e uso do arquivo de paginação (swap), lidos pela biblioteca de sistema `VMStatisticsCompat`.
- **Disco e Armazenamento:** Capacidade usada e disponível, espaço purgável, taxa de leitura e gravação, totais lidos e gravados, status SMART, temperatura e horas ligadas quando o disco informa, e ejeção de discos externos.
- **Rede:** Taxa de transferência em tempo real (download e upload), gráficos dinâmicos de tráfego, total da sessão, tráfego por app, endereços IP e teste de velocidade sob pedido.
- **Energia e Bateria:** Porcentagem de carga, estado da fonte de alimentação, consumo do sistema e do adaptador em Watts, taxa de descarga/recarga da bateria, temperatura da bateria, saúde (capacidade máxima relativa), contagem de ciclos, apps que mais consomem energia e bateria de acessórios Bluetooth (com a permissão de Bluetooth).
- **Dispositivos Conectados:** Inventário dos periféricos USB externos conectados.
- **Fan Control (Ventoinhas):** Velocidade atual em RPM das ventoinhas do sistema, com modos sistema, manual e curva de temperatura através do SMC. No modo manual vale o piso de segurança de 1200 RPM (DEC-021); um estado térmico sério ou crítico devolve o controle ao firmware.
- **Leituras na Barra de Menus (DEC-003):** O usuário pode habilitar a exibição compacta de métricas selecionadas (como temperatura da CPU ou uso de RAM) diretamente na barra de menus. O padrão exibe apenas o ícone discreto do aplicativo.

---

## 3. Uninstaller (Desinstalador de Aplicativos)

Desinstalação profunda de aplicativos do macOS, garantindo que nenhum resíduo permaneça no disco:

- **Detecção Completa de Sobras:** Além do arquivo `.app` em `/Applications`, o módulo inspeciona detalhadamente:
  - `~/Library/Application Support/` e `/Library/Application Support/`
  - `~/Library/Caches/` e `/Library/Caches/`
  - `~/Library/Preferences/` (arquivos `.plist`)
  - `~/Library/Containers/` e `~/Library/Group Containers/`
  - `~/Library/Saved Application State/`
  - `~/Library/Logs/`, `~/Library/WebKit/`, agentes de inicialização em `LaunchAgents/` e daemons em `/Library/LaunchDaemons/`
- **Seleção Padrão (DEC-009):** Nada vem pré-selecionado na lista de sobras.
- **Atalho "Selecionar Tudo":** Permite marcar de uma só vez todos os arquivos residuais detectados para remoção rápida.
- **Exclusão Segura:** Move os itens para a Lixeira do macOS. O que a Lixeira não consegue mover (itens de outro dono ou em `/Library`) vai em um único lote ao Finder, que pede a senha de administrador. Apps instalados pelo Homebrew são removidos pelo `brew`; quando ele pede senha, a desinstalação é concluída no Terminal.

---

## 4. Cleaner e Tarefas de Manutenção

Combina ferramentas de higienização de disco e utilitários de manutenção do sistema operacional:

### Cleaner
- Localização de restos de apps desinstalados, itens de início órfãos, caches, registros, lixo de desenvolvimento (compilações e simuladores do Xcode), caches e dados de sites dos navegadores, backups de iPhone, capturas de tela esquecidas, caches de pacotes e a Lixeira. Os itens removidos vão para a Lixeira.
- **Arquivos Grandes e Antigos:** Lista os arquivos do Mac por tamanho e idade; nada vem marcado.
- **Conversas Antigas do Claude Code (DEC-020):** Varredura segura da pasta `~/.claude/projects`, identificando pares `<uuid>.jsonl` e suas respectivas subpastas `<uuid>/`.
  - Critério de idade configurável: 7, 14, 30 (padrão), 60 ou 90 dias sem modificação, ou desativado.
  - Segurança ativa: itens desta categoria sempre nascem desmarcados e não são removidos por rotinas automáticas de limpeza, exigindo confirmação explícita do usuário. Sessões vinculadas ao aplicativo Desktop do Claude são preservadas.
- **Agendador Opcional:** Por padrão o agendamento de limpeza é desligado. Se configurado expressamente pelo usuário (diário ou semanal), limpa só a parte segura, no máximo uma vez ao dia e apenas com uma superfície do Hexa visível (DEC-002).

### Tarefas de Manutenção
- **Liberar DNS (DEC-035):** Limpa a base local do Directory Services (`dscacheutil -flushcache`) e reinicia o daemon `mDNSResponder`. Solicita a senha de administrador através da autenticação nativa do macOS apenas durante a execução.
- **Purge de Memória:** Executa a chamada de sistema para desalocar blocos inativos e caches de disco da memória RAM, com senha de administrador.
- **Remover Snapshots Locais:** Exclui snapshots temporários do Time Machine no sistema de arquivos APFS que ocupam espaço do armazenamento.
- **Reconstruir Launch Services:** Repara associações defeituosas de arquivos, ícones genéricos e entradas duplicadas do menu "Abrir Com...".
- **Reindexar Spotlight:** Reconstrói a base de dados do serviço de busca do sistema para corrigir pesquisas lentas ou incompletas, com senha de administrador.
- **Limpeza do Homebrew:** Remove versões antigas de fórmulas e caches de download da pasta de pacotes do Homebrew.

---

## 5. Media Tools (Ferramentas de Mídia)

Quatro ferramentas locais de manipulação de mídia, com aceleração de hardware nativa:

- **Compressor de Vídeo:** Reduz o tamanho de vídeos por corte do trecho, resolução e qualidade, com os encoders de hardware H.264 e HEVC (H.265) do Apple Silicon via AVFoundation.
- **Criador de GIF:** Converte um trecho de vídeo em GIF, com corte, largura, taxa de quadros e repetição ajustáveis.
- **Compressor de Imagem:** Comprime e converte para JPEG, HEIC, PNG ou PDF, com redimensionamento, marca d'água opcional e remoção de metadados.
- **Extrator de Texto:** Lê imagens por OCR com o Apple Vision e grava o texto reconhecido em arquivo.

---

## 6. Dynamic Island (Entalhe Dinâmico)

Redesenho completo da interação com o entalhe físico (notch) dos MacBooks:

- **Controles como Padrão (DEC-006 e DEC-039):** Ao clicar ou expandir o notch, o Hexa apresenta o painel de Controles com acesso imediato às ferramentas essenciais do sistema, mesmo durante a reprodução de mídia. Controles não pode ser escondido da ilha.
- **Tamanho Exato do Notch (DEC-007):** As dimensões da ilha retraída correspondem perfeitamente às medidas do entalhe de hardware de cada tela da Apple.
- **Barra de Atalhos Fixa (DEC-008 e DEC-015):** Exibida exclusivamente no modo expandido, posicionada abaixo do conteúdo central. Organizada em grade uniforme de até 2 linhas com 6 atalhos essenciais predefinidos (Explorar, Timer, Mixer, Música, Keep Awake e Calendário), eliminando a necessidade de rolagem horizontal. O botão de Ajustes permanece fixo no cabeçalho superior.
- **Extensões Modulares:**
  - **Reproduzindo Agora:** Exibe capa do álbum, título da faixa, artista e barra de reprodução. A abertura automática nessa página, com a ilha fechada mostrando a faixa, é opt-in na aba Atividade (DEC-023).
  - **Letra e A Seguir:** Letra da música atual e as próximas músicas informadas pelo reprodutor.
  - **Equalizador em Tempo Real:** Barras que seguem o som do reprodutor. Começa desligado, porque usa a permissão de áudio dos aplicativos.
  - **Notificações:** Novas notificações do sistema na ilha. A opção de fechar o banner original do macOS só aparece no macOS 27 ou mais novo (DEC-032).
  - **Timer:** Temporizadores, cronômetro e sessões de foco.
  - **Downloads:** Acompanha os arquivos que chegam em uma pasta escolhida pelo usuário.
  - **Calendário:** Apresentação do mês e dos próximos compromissos.
  - **Acessórios:** Mostra acessórios Bluetooth conectados e avisa uma vez quando a bateria cai para 20%.
  - **Observar:** Transforma uma área de qualquer janela em atividade ao vivo, com aviso quando ela muda, termina ou mostra o que o usuário espera.
  - **Gestos:** Abre e fecha a ilha com a rolagem e troca de música deslizando.

---

## 7. Mixer de Áudio por App

Ajuste individual de volume por aplicativo sem instalação de drivers invasivos:

- **Tecnologia sem Driver de Áudio:** Controla o volume de cada aplicativo diretamente via CoreAudio, sem instalar extensões de kernel (kexts) ou softwares virtuais que possam afetar a estabilidade do sistema operacional. Usa a permissão de áudio dos aplicativos.
- **Volume e Saída por App:** Cada aplicativo vai de 0 a 200% e pode tocar em um dispositivo de saída próprio.
- **Persistência de Níveis:** Os volumes definidos para cada software são lembrados e reaplicados automaticamente assim que o programa volta a ser executado.
- **Recuperação de Áudio Pós-Sono (DEC-002):** Caso um aplicativo com volume alterado esteja reproduzindo som, o módulo realiza uma verificação leve a cada 1,5 segundos para detectar e recuperar canais de áudio que tenham congelado após a suspensão do Mac. A verificação encerra-se assim que o áudio cessa.

---

## 8. Keep Awake (Manter Acordado)

Controle de prevenção contra repouso e desligamento da tela:

- **Integração Nativa:** Utiliza as APIs oficiais de gerenciamento de energia (`IOPMAssertionCreateWithName`) para garantir que compilações, downloads ou apresentações não sejam interrompidos.
- **Modos de Duração:**
  - Modo contínuo (até o cancelamento manual).
  - Modo temporizado: intervalos predefinidos (15 min, 30 min, 1h, 2h, 4h, 8h).
  - Automações contextuais: manter acordado enquanto um monitor externo estiver conectado, enquanto o Mac estiver na fonte de energia ou enquanto um aplicativo escolhido estiver em execução, combinadas por "qualquer condição" ou "todas as condições".
- **Mover Cursor Levemente:** Opção que, durante uma sessão, move o cursor um pouco no intervalo escolhido.
- **Operação com Tampa Fechada (Clamshell):** Mantém o Mac processando mesmo com a tampa do notebook fechada, via `pmset disablesleep`, com senha de administrador e uma regra `sudoers` instalada pelo app. A tela segue no brilho atual, sem escurecer (DEC-013).
- **Piso de Segurança de Bateria (DEC-034):** Encerra preventivamente a sessão de Keep Awake e bloqueia as automações caso a bateria do notebook atinja o patamar de segurança selecionado pelo usuário (Nunca, 5%, 10% padrão, ou 20%).
- **Indicador Visual na Barra de Menus (DEC-018):** O ícone do Hexa ganha tonalidade laranja permanente durante uma sessão ativa de Keep Awake, permitindo identificar o estado à distância.

---

## 9. Luz do Teclado

Ajuste da retroiluminação do teclado para notebooks Mac com chip Apple Silicon, no mesmo recurso do Brilho de Tela (tela **Telas**):

- Controle de intensidade com controle deslizante contínuo, além de atalhos globais opcionais para aumentar e diminuir a luz.
- O nível atual é lido do hardware quando uma superfície que o mostra abre ou um atalho é pressionado, em vez de vir do último valor gravado pelo app, então mudanças feitas pela Central de Controle ou pelo ajuste automático do macOS são respeitadas.

---

## 10. Brilho de Tela

Central integrada para controle de monitores múltiplos (tela **Telas** no app):

- **Tela Interna e Telas Apple:** Brilho pelo controle de brilho do próprio sistema.
- **Monitores Externos via DDC/CI:** Envia comandos de controle de tela (Display Data Channel) diretamente aos monitores conectados via HDMI, DisplayPort ou Thunderbolt, permitindo alterar o brilho físico do monitor externo, inclusive pelas teclas de brilho ou atalhos globais.
- **Escurecimento por Software (Software Dimming - DEC-013):** Para telas cuja conexão não aceita DDC (adaptadores HDMI, TVs), o controle escurece a própria imagem pela curva de gama. Em monitores DDC, uma faixa opcional por software estende o escurecimento abaixo do mínimo do monitor.
- **Ligar e Desligar Telas:** Cada tela conectada pode ser desligada e religada pelo app, sem alterar o arranjo de telas salvo no sistema.
- **Sem Hacks Arriscados:** O módulo não realiza elevação artificial de brilho acima do teto XDR nem altera parâmetros arriscados do painel.

---

## 11. Kill Process + Port Manager

Conjunto de utilitários rápidos para desenvolvedores e administradores de sistema:

### Kill Process
- Lista de processos ativos em execução no macOS com busca instantânea por nome, caminho ou número de PID.
- Exibição de consumo de CPU e memória RAM, com os processos auxiliares agrupados sob o app responsável. Processos críticos do sistema ficam protegidos.
- Encerramento padrão gracioso (`SIGTERM`) e opção de encerramento imediato forçado (`SIGKILL`) para destravar tarefas que congelaram.

### Port Manager
- Mapeia instantaneamente as portas TCP locais em estado de escuta (`LISTEN`).
- Indica claramente qual processo, PID e binário está ocupando cada porta.
- Ação em um clique para matar o processo que está segurando a porta, solucionando conflitos comuns em desenvolvimento web (como portas 3000, 8080, 5000, etc.).

---

## 12. Captura de Tela + OCR

Ferramenta completa para capturas gráficas e extração óptica de caracteres:

### Captura de Tela
- **Modos de Captura:** Seleção de área ou de janela, captura da tela cheia e captura com rolagem.
- **Atalhos Globais:** Atalhos de teclado configuráveis, desligados por padrão (captura, tela inteira, editar a captura mais recente, editar a imagem copiada, capturas recentes e copiar texto).
- **Salvamento Direto por Padrão (DEC-030):** Ao realizar uma captura em uma instalação nova, o arquivo é salvo imediatamente na pasta de capturas escolhida pelo usuário, garantindo que nada se perca.
- **Prévia Pós-Captura Opt-In (DEC-024):** A exibição de prévias flutuantes na tela ou na Dynamic Island é desligada por padrão. O usuário pode ativá-la nos Ajustes de Captura caso prefira inspecionar a imagem antes de salvar.
- **Editor Embutido:** Ferramentas de anotação incluindo setas, retângulos, elipses, linhas, traço livre, marca-texto, números sequenciais, texto, adesivos, recorte, pixelização e tarja para ocultar senhas e informações confidenciais.

### OCR de Tela
- Reconhecimento óptico de caracteres baseado na tecnologia nativa Apple Vision.
- Permite desenhar um retângulo sobre qualquer texto exibido no monitor (inclusive em fotos, diagramas, vídeos ou textos não copiáveis) e envia o conteúdo lido diretamente para a área de transferência, com leitura opcional de QR codes.

---

## 13. Dock em uma Tela

Mantém o Dock na tela escolhida quando há mais de um monitor:

- Os últimos pontos da borda do Dock das outras telas ficam fora de alcance do ponteiro, ao mover ou arrastar, para que o macOS nunca receba o pedido de mover o Dock. No resto da tela o ponteiro anda livremente; segurar Option libera essa borda para mover o Dock de propósito.
- Enquanto a tela escolhida não estiver conectada, o Dock fica na tela principal. Um botão traz o Dock de volta sob demanda, e uma opção o traz de volta após o repouso e mudanças de tela, só com o Mac desbloqueado.
- Depende de "As telas têm Espaços separados" ligado no macOS; com a opção desligada, o próprio sistema mantém o Dock na tela principal.
- Requer Acessibilidade, para ler onde o Dock está e recuar o ponteiro antes da borda.

---

## 14. Ícones da Menu Bar

Separa os itens de outros apps na menu bar em seções visível e oculta (DEC-041):

- **Fronteira pelo Chevron:** O módulo adiciona um chevron à menu bar. Os itens de outros apps à esquerda dele ficam ocultos; os da direita, sempre visíveis. Os itens são movidos entre as seções segurando Command e arrastando através do chevron. A ocultação vale por app: se um app tem um item na seção visível, todos os itens dele ficam visíveis.
- **Revelar e Recolher:** O módulo inicia recolhido. Um clique no chevron mostra os itens ocultos; outro clique recolhe na hora. O chevron mostra `<` recolhido e `>` aberto.
- **Prazo de Recolhimento:** Instantâneo, 5 segundos (padrão) ou 10 segundos. Instantâneo recolhe ao clicar fora da menu bar ou pressionar Escape; com prazo, cada clique na menu bar reinicia a contagem, e Escape também recolhe.
- **Segurança:** Itens cuja identidade ou posição não puder ser lida ficam visíveis. Desligar o módulo libera todos os itens.
- **macOS 27 ou mais novo:** Usa uma restrição de visibilidade do próprio sistema, que exige Acessibilidade e só funciona em build assinado com Developer ID; em outro build o módulo avisa que não pode ocultar com segurança. Os itens do próprio macOS (Central de Controle, Tocando Agora, relógio etc.) ficam sempre visíveis.
- **Até o macOS 26:** Usa um separador que, recolhido, empurra para fora da tela os itens à esquerda dele.

---

## Desinstalação Completa do Hexa (DEC-031)

O Hexa respeita a máquina do operador e oferece um procedimento completo de remoção:
- Localizado em **Avançado** (grupo Preferências da barra lateral), botão **Desinstalar o Hexa completamente**, com confirmação.
- A ação devolve a rotação das ventoinhas ao controle do firmware do Mac, remove o executável auxiliar `FanControlHelper`, elimina a entrada nos Itens de Início de Sessão, restaura o repouso, remove a regra de `sudoers` associada ao modo de tampa fechada, devolve os atalhos do macOS assumidos, apaga os ajustes, move caches, dados e o próprio aplicativo para a Lixeira e fecha o Hexa. O macOS pode pedir a senha.
