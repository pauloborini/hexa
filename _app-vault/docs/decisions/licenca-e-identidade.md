# licenca-e-identidade

Affects: [app-updates, monitor, uninstaller, cleaner, maintenance-tasks, media-tools, dynamic-island, mixer, keep-awake, keyboard-light, screen-brightness, kill-process, port-manager, screen-capture]

### DEC-010 — Licença

GPL-3.0-or-later.

### DEC-028 — Titular do copyright e atribuição de origem

O titular do copyright do hexa é Paulo Borini. Arquivos derivados do projeto de origem mantêm o aviso de copyright original ao lado do aviso do titular; arquivos novos trazem só o aviso do titular. O texto da GPL acompanha o repositório (raiz) e o app distribuído, e o README traz uma linha de atribuição dizendo que o hexa é obra derivada. Essa atribuição é a única menção à origem permitida em arquivo versionado.

Decisão do operador em 2026-10-22.

### DEC-025 — Código-fonte público no lançamento

O repositório do hexa no GitHub passa a ser público junto com a primeira versão distribuída (0.1.0). É a forma de oferecer o código-fonte exigida pela GPL (DEC-010) e o destino do link "Ver no GitHub" do Sobre. Antes de abrir o repositório: texto da licença na raiz e no app, avisos de copyright conforme a licença, limpeza de referências e decisão sobre o histórico. Registrar a decisão não autoriza tornar o repositório público, criar tag nem publicar artefatos; cada passo exige pedido explícito.

Decisão do operador em 2026-10-22.

### DEC-029 — Histórico novo na publicação

O repositório público começa com um único commit, a partir da árvore já limpa, e o histórico de desenvolvimento atual fica guardado num repositório privado de arquivo. Isso só acontece depois de tudo finalizado, quando o operador julgar o hexa pronto e pedir explicitamente; até lá, o histórico atual segue como está.

Decisão do operador em 2026-10-22.

### DEC-042 — Release nasce no repositório público

A troca de histórico da DEC-029 acontece antes da primeira release. O repositório público novo, com um único commit, recebe a tag `v0.1.0`, a release no GitHub e o cask do Homebrew. O repositório privado de arquivo guarda só o histórico de desenvolvimento, sem release nem tag de distribuição. Registrar a ordem não autoriza criar repositório, tornar público, criar tag nem publicar; cada passo exige pedido explícito.

Decisão do operador em 2026-11-09.

### DEC-026 — Identificador do app

O hexa usa o identificador `io.github.pauloborini.hexa`, no domínio gratuito do GitHub do operador. O helper do FanControl usa `io.github.pauloborini.hexa.fan-control` e o build de desenvolvimento usa `io.github.pauloborini.hexa.dev`. A troca acontece antes da 0.1.0, sem migração de ajustes, porque ainda não há usuários.

Decisão do operador em 2026-10-22.

### DEC-011 — Identidade própria

O hexa tem identidade própria (nome, logo e visual); a marca não reaproveita identidade de terceiros. Ícones de interface usam a família Lucide, licenciada e distribuída localmente, com traço consistente e sem personalização pelo usuário. O ícone foi redesenhado (Conceito A "Segmento aberto", DEC-017) e substituiu a base temporária; restam a chegada do icns ao Dock via `build.sh` e o refinamento do squircle, no fechamento do roadmap.

_Alterado 2026-10-07 — era: o ícone usaria base temporária com tema hexadecimal até o redesenho. Motivo: redesenho concluído e aplicado (DEC-017; commits 0935650 e 4716d09)._

_Alterado 2026-10-07 — era: ícones de terceiros não eram reaproveitados. Motivo: operador aprovou Lucide para todos os ícones de interface, mantendo a logo própria._

### DEC-017 — Design system próprio

A identidade visual do hexa segue design system próprio: marca do Conceito A, "Segmento aberto" (hexágono segmentado com um segmento solto e núcleo aceso em latão), wordmark "hexa" em minúsculas com "a" itálico (Instrument Serif), paleta tinta/bone/latão e tipografia Instrument Serif + Manrope + IBM Plex Mono, com dois temas (escuro como palco padrão e claro). O latão é a cor da MARCA (logo e wordmark); os papéis de accent de UI (seleção, foco, borda informativa, rótulo de seção) usam accent neutro quase sem cor (família taupe derivada de ink/bone), por pedido do operador por UI "neutra e minimalista". O registro canônico de tokens, medidas, matriz de contraste e primitives vive em `_app-vault/specs/design-system.md`; a UI consome tokens semânticos, não literais. O asset do redesenho (Conceito A) substituiu a base temporária da DEC-011; restam o icns no Dock via `build.sh` e o refinamento do squircle, no fechamento do roadmap.

_Alterado 2026-10-07 — era: o ícone seguia a DEC-011 até o asset do redesenho substituir a base temporária. Motivo: asset do redesenho gerado e aplicado; pendência de Dock registrada para o fechamento._

_Alterado 2026-10-07 — era: accent de UI em latão. Motivo: operador pediu accent neutro e minimalista._

### DEC-018 — Painel rápido e janela de funcionalidades

O painel da menu bar apresenta consultas e atalhos rápidos, com acionamento imediato de Manter acordado. As operações completas e configurações vivem em janela única com sidebar unificada e conteúdo à direita. Dentro de cada tela de módulo, a alternância Operação/Ajustes no cabeçalho separa a visão de uso da visão de configuração, sem janela própria. Cada tela de módulo integra a utilização da ferramenta e suas preferências de configuração. A linguagem visual segue DEC-017, com superfícies recessadas suavizadas e compartilhadas por token.

O ícone da menu bar é fixo: glifo do hexa no tema padrão; Manter acordado ativo usa laranja fixo, sem personalização de símbolo ou cor pelo usuário. Leituras opt-in continuam conforme DEC-003.

Na UI, estados e dados usam canais neutros, texto e forma; laranja é reservado ao indicador de sessão Manter acordado ativa. A paleta da marca e as cores do conteúdo editado/exibido permanecem conforme DEC-017.

_Alterado 2026-10-14 — era: sem separação entre funcionalidades e ajustes na janela única. Motivo: operador confirmou manter a alternância Operação/Ajustes no cabeçalho do módulo (ARCH-02)._
_Alterado 2026-10-10 — era: ajustes ocupavam seção separada da janela de operações. Motivo: unificação da experiência em janela única e sidebar única com operação e configuração na mesma tela._
_Alterado 2026-10-07 — era: operações completas em janela independente de Ajustes. Motivo: operador solicitou unificar ambas na mesma janela e identidade visual._
