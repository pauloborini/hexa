# dynamic-island

Affects: [dynamic-island]

### DEC-006 — Controles sempre como interface padrão

Na Dynamic Island, a interface padrão é sempre a de controles, mesmo com o player ativo. O player não assume a posição padrão.

### DEC-023 — Reproduzindo Agora automático é opt-in

A fábrica permanece em Controles (DEC-006). O usuário pode ligar, na aba Atividade da Dynamic Island, a abertura automática de Reproduzindo Agora: com a opção ligada, a ilha fechada mostra a faixa quando houver reprodução e a abertura vai para essa página. Desligada, a ilha não troca sozinha para Reproduzindo Agora.

_Alterado 2026-11-06 — era: aba Comportamento. Motivo: a ilha fechada é configurada na aba Atividade, onde a opção passou a viver (recomendação aceita na auditoria de experiência da Dynamic Island)._

### DEC-007 — Tamanho padrão do notch

O tamanho padrão da ilha é exatamente o tamanho do notch do Mac.

### DEC-008 — Barra de atalhos fixa embaixo do notch

Os botões de acesso rápido ficam em uma única grade fixa abaixo do conteúdo do notch expandido, com células uniformes em até duas linhas, sem scroll horizontal. O preset padrão é composto por 6 atalhos diretos (.explore, .timer, .mixer, .music, .keepAwake, .calendar), eliminando a necessidade do botão Todos na disposição padrão. O botão de Ajustes é fixo e permanentemente visível no cabeçalho ao lado do chevron de recolher. Excedentes decorrentes de customização manual continuam acessíveis pelo botão Todos. Preferências anteriores são migradas preservando ordem e nomes, retirando Ajustes da grade para o cabeçalho.
_Alterado 2026-10-11 — era: Ajustes ocupava slot na grade e excedentes ficavam em Todos. Motivo: operador aprovou migrar Ajustes para o cabeçalho fixo ao lado do chevron e preencher a grade de 6 células com as ferramentas diretas._
_Alterado 2026-10-08 — era: linha ajustável de ícone + texto, com atalhos também em Controles. Motivo: operador aprovou grade única e gerenciamento centralizado, sem duplicações._

### DEC-015 — Barra de atalhos só no modo expandido

A barra de atalhos da ilha (DEC-008) existe apenas no modo expandido e não tem gatilho próprio: valem o gatilho e as exclusões já praticados pelo modo expandido da ilha. No modo compacto, a ilha não mostra botões.

### DEC-032 — Esconder aviso do sistema só no macOS 27 ou mais novo

A opção da ilha que fecha o banner original do macOS só aparece no macOS 27 ou mais novo. Do macOS 14 ao 26, fechar o banner pode impedir que a notificação chegue ao Centro de Notificações, e a única cópia ficaria na memória da ilha; nessas versões a ilha mostra a notificação e o banner do sistema segue normal.

Decisão do operador em 2026-10-22.

### DEC-036 — Falha ao forçar encerramento na ilha

Quando "Forçar encerramento" falha numa lista de uso dentro da ilha, a ilha mostra um aviso curto por alguns segundos, sem janela modal, no lugar do beep.

Decisão do operador em 2026-10-22.

### DEC-039 — Controles sempre disponível na ilha

O módulo Controles não pode ser escondido da ilha, porque é a interface padrão da Dynamic Island (DEC-006). Uma preferência que tente esconder Controles é ignorada pelo serviço: a seção continua disponível na lista de seções e na disposição da ilha, qualquer que seja o valor guardado.
