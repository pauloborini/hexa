# hexa — design system (registro canônico)

> Status: aprovado pelo operador em 2026-10-06, a partir do protótipo `.app-work/archive/design-prototipos/identidade-visual.html` (Conceito A "Segmento aberto") e do styleguide vivo `.app-work/archive/design-prototipos/design-system.html`.
> Decisão de produto: DEC-017 (`_app-vault/docs/decisions/licenca-e-identidade.md`), junto com DEC-011 (identidade própria).
> Norma de consumo: `project-rules/rules/design-system.md`. Este arquivo registra VALORES e CONTRATOS; não prescreve implementação de código.

## 1. Marca

### 1.1 Logo: Conceito A, "Segmento aberto"

Hexágono segmentado que carrega o conceito do app: a forma só se completa quando acionada (sob demanda, DEC-002); o núcleo aceso é o módulo em uso.

Construção (viewBox 48, centro 24,24, hexágono pointy-top r=15, stroke `round`):

- Vértices: (24,9), (36.99,16.5), (36.99,31.5), (24,39), (11.01,31.5), (11.01,16.5).
- 5 segmentos fechados: linha base (25.73,10) → (35.25,15.5) rotacionada 60°, 120°, 180°, 240° e 300° em torno de (24,24).
- Segmento aberto (superior direito): linha (29.14,9.08) → (34.34,12.08), deslocada 2.5 para fora, na cor de accent.
- Núcleo: círculo em (24,24), na cor de accent.

Peso por tamanho (stroke / raio do núcleo): 48 px ou mais: 2 / 2.2 · 24 px: 3 / 2.8 · 16 px: 4 / 3.4.

- Uso mínimo: 16 px. Na menu bar, o tamanho deriva da espessura real da barra (sem respiro extra; a tinta do glifo ocupa 62,5% da altura do viewBox e já carrega respiro próprio), com teto de 28 px (implementado em `HexaBrandGlyph.menuBarSize`), sem texto ao lado.
  _Alterado 2026-10-07 — era: "Na menu bar, 15-17 px". Motivo: ampliação da marca na menu bar aprovada pelo operador no fechamento M1-M8; o valor fixo deu lugar ao tamanho derivado da barra._
  _Alterado 2026-10-07 — era: "espessura da barra menos 2 px de respiro, com teto de 24 px". Motivo: Fase 2 do redesign; a marca ainda parecia pequena, então o respiro caiu para 0 (a tinta tem margem própria) e o teto subiu para 28 px, cerca de 10% a mais de tinta real._
- Clear space: metade da largura da marca em cada lado.
- A marca nunca recebe gradiente, sombra ou contorno externo.

### 1.2 Wordmark

- "hexa" sempre em minúsculas, Instrument Serif regular, "a" em itálico na cor de accent, tracking -0.02em.
- Lockup padrão: marca + wordmark, gap 0.5 da altura da marca.
- Variante técnica: prefixo "0x" em `data` mono, para superfícies de desenvolvedor (Kill Process, Port Manager).
- Sem versão em caixa alta; a minúscula é a voz da marca.

## 2. Camadas de token

Três camadas. Componente consome token semântico (ou de componente quando o contrato exigir); semântico consome base; NUNCA literal direto na view. Nomes em inglês para código; esta spec documenta em PT-BR.

### 2.1 Camada 1: base (paleta da marca)

| Token | Valor | Papel |
|---|---|---|
| `ink` | #201D17 | tinta (fg escuro sobre claro) |
| `bone` | #F6F4EE | osso (fg claro sobre escuro e base clara) |
| `brass` | #A3813C | latão (paleta da MARCA no tema claro: logo, wordmark; não alimenta papel de UI) |
| `brassBright` | #CFA955 | latão claro (paleta da MARCA no tema escuro: logo, wordmark; não alimenta papel de UI) |
| `coal` | #17140F | carvão (base escura) |
| `panelDark` | #211D15 | painel escuro elevado |
| `insetDark` | #1B1812 | nicho escuro (menu bar, notch) |
| `raisedLight` | #FBFAF6 | cartão claro elevado |

### 2.2 Camada 2: semânticos (por tema)

| Token | Tema escuro | Tema claro | Papel |
|---|---|---|---|
| `surface.base` | #17140F | #F6F4EE | fundo da superfície de trabalho |
| `surface.raised` | #211D15 | #FBFAF6 | cartão/painel elevado |
| `surface.inset` | #1B1812 | #ECE8DD | nicho (menu bar, notch, campo) |
| `fg.primary` | #F6F4EE | #201D17 | texto principal |
| `fg.secondary` | bone @ 66% | #5A554A | texto de apoio |
| `fg.tertiary` | bone @ 55% | ink @ 64% | metadado discreto (resolvidos: #96938C s/ raised escuro; #6F6D67 s/ raised claro) |
| `fg.disabled` | bone @ 50% | ink @ 50% | desabilitado |
| `fg.inverse` | #201D17 (ink) | #F6F4EE (bone) | texto sobre preenchimento invertido claro (ex.: dia selecionado do calendário do notch); mesmos valores do par auditado fg.primary/base claro (15.28, §6) |
| `border.hairline` | bone @ 13% | ink @ 14% | divisor decorativo |
| `accent.solid` | #A8A199 | #6E675C | accent não-texto: borda, fill de seleção, foco (taupe neutro, derivado de bone) |
| `accent.text` | #B8B2A9 | #5C564B | accent como texto (4.5:1 garantido, spec §6) |
| `focus.ring` | #A8A199 | #6E675C | anel de foco |
| `selection.bg` | taupe #A8A199 @ 12% | taupe #6E675C @ 12% | fundo de seleção (resolvido: #312D25 s/ raised e #282520 s/ base escuro; #EAE8E4 s/ raised e #E6E3DC s/ base claro) |
| `brand.solid` | #CFA955 | #A3813C | latão da MARCA: segmento aberto e núcleo do glifo (Conceito A) |
| `brand.text` | #CFA955 | #84682C | latão da MARCA como texto: "a" itálico do wordmark |
| `status.ok` | #B8B2A9 | #5C564B | sucesso/atualizado |
| `status.warning` | #B8B2A9 | #5C564B | aviso/pendente |
| `status.danger` | #B8B2A9 | #5C564B | erro/risco |

Regras:

- Alfa é registrado como intenção (@ 66%); o valor resolvido depende da superfície sob ele. Par novo com alfa: medir sobre a superfície real de uso.
- **2026-10-07:** o accent de UI passou a ser neutro quase sem cor (família taupe derivada de ink/bone, pedido do operador por UI "neutra e minimalista"). O latão (`brass`/`brassBright`, tokens `brand.*`) fica reservado à MARCA: logo Conceito A e wordmark. Nenhum papel de UI consome latão.
- `accent` (taupe) é sinal raro de seleção e foco. Usos permitidos: seleção, foco, borda informativa, rótulo de seção (`SectionLabel`) e valor de acento em `DataRow`. NÃO usa accent para loading, erro ou sucesso (papéis de `status.*`).
- Status nunca colapsa em accent nem em `fg.secondary`. `PanelMetricColor` (dataviz) consome tokens semânticos neutros (mapeamento em `Sources/Hexa/UI/Theme.swift`: `accent.solid`, `fg.secondary`, `fg.primary`, `accent.text`); a diferenciação de gráficos vive no rótulo/forma. Os nomes legados de canal permanecem apenas como API de consumo.

### 2.3 Camada 3: componente

Só quando um contrato estável de primitive exigir (ex.: `DataRow.valueAccent`). Criar exige papel não atendido pelo vocabulário acima, registrado aqui antes do uso.

`KeyCap` (`Sources/Hexa/UI/SharedUI.swift`) consome o token de geometria `HexaTheme.hairline` já existente (§4), com 1 px no contorno decorativo. A cor deriva de `fg.primary` com 14% de opacidade; não cria token de cor nem sustenta legibilidade.

#### Tokens de vibrancy/vidro do painel (`PanelSurface`, registro 2026-10-10)

`PanelSurface` (`Sources/Hexa/UI/Theme.swift`) é a fonte canônica dos tokens de vidro/vibrancy do painel rápido da menu bar e do backdrop de HUD flutuante (`HUDBackdrop`); `Sources/Hexa/UI/SharedUI.swift` (`panelGlassSurface`) e as seções do painel são consumidores, nunca fontes. Valores atuais, por tema — **valores inalterados; registro de consumo, não de nova cor** (nenhum par FG/BG da §6 muda):

| Token | Claro | Escuro | Papel |
|---|---|---|---|
| `baseFill` | branco @ 68% | preto @ 42% | fill base do vidro do painel |
| `cardFill` | branco @ 38% | branco @ 7,5% | fill de cartão sobre o vidro |
| `controlFill` | preto @ 5,5% | branco @ 8,5% | fill de controle dentro do vidro |
| `border` | preto @ 9% (24% com contraste aumentado) | branco @ 11% (28% com contraste aumentado) | contorno que separa superfícies de vidro |
| `raisedFill` | branco @ 88% | branco @ 14% | controle que repousa SOBRE o vidro (toggle, knob) |
| `raisedBorder` | preto @ 7% (22% com contraste aumentado) | branco @ 16% (32% com contraste aumentado) | contorno do controle elevado |
| `raisedShadow` | preto @ 14% | preto @ 38% | sombra do controle elevado |
| `rimHighlight` | branco @ 95% → 12% (gradiente vertical) | branco @ 30% → 4% (gradiente vertical) | aresta iluminada do vidro |
| `plateTint` | branco | preto | plate opaco de contraste sobre o material do HUD (`HUDBackdrop` com `contrast: .high`); a opacidade vem do `plateOpacity` do backdrop (0,5 claro / 0,55 escuro), não do tinte |

Escopo delimitado: material e vidro do painel rápido (MenuPanel) e do backdrop de HUD flutuante (shelf, switcher, HUD de feedback de corte). São tintes de vibrancy sobre material do sistema, não superfícies opacas: os pares da §6 valem sobre superfícies opacas; sobre o vidro vale a ressalva geral já registrada no §9 (a tabela mede superfícies opacas e não declara contraste sobre vidro ou wallpaper). Os tokens de `border`/`raisedBorder` com contraste aumentado são a exceção de acessibilidade já prevista no desenho dos cartões (§7, HexaCard).

## 3. Tipografia

| Papel | Fonte | Medida | Uso |
|---|---|---|---|
| `display` | Instrument Serif 400 (itálico permitido) | 20-64 / 1.1, tracking -0.01em | wordmark, título de painel, numerais de seção |
| `heading` | Manrope 600 | 15 / 20, tracking -0.01em | título de agrupamento |
| `body` | Manrope 400 | 13 / 18 | corpo de UI, listas, menus |
| `label` | Manrope 500 | 12 / 15 | rótulo de controle |
| `micro` | IBM Plex Mono 500 | 10.5 / 13, uppercase, tracking 0.16em | etiqueta de seção |
| `data` | IBM Plex Mono 400/500 | 12.5 / 16, tabular-nums | métrica, valor, status pontual |

- Fallbacks: Georgia / Helvetica Neue / Menlo.
- Mono é canal técnico e de dados: só `micro` e `data`. Não transformar metadado comum em mono só por contraste.
- Hierarquia nesta ordem: posição e agrupamento, superfície, espaço, contraste, estado, tamanho e, por último, peso. Peso acima de 600 é exceção com motivo.
- Densidade de título: sem caixa alta fora de `micro`.
- Medidas próprias de SF Symbols são geometria gráfica, não papel de texto. Imagens podem manter tamanho funcional, sem transportar essas fontes para Text.
- Exceções funcionais delimitadas: o texto de anotação em `ScreenshotEditorView.textEditorOverlay` acompanha tamanho/zoom do conteúdo exportado; o editor PlainTextEditor acompanha tamanho configurável do documento usando Manrope; métricas reais e sua prévia compartilham as medidas compactas do MenuBarRenderer e IBM Plex Mono; o keycap de atalho nos tiles de módulo do notch (`NotchSectionsView.tile`, `"⌥⌘" + shortcutKey.uppercased()` em papel `label`) tem caixa alta fora de `micro` porque representa tecla física (keycap), não rótulo textual — escopo delimitado a esses tiles. Não são exceções para textos comuns de UI.
- **Tokens de página (2026-10-08):** todo título de feature/página usa `HexaFontRole.featureTitle` (Instrument Serif, `PageTypography.title` = 28) e todo subtítulo usa `featureSubtitle` (papel `body`). O título de seção interna é o SectionLabel (micro, §7) e é DISTINTO do subtítulo. Nenhuma tela define tamanho de título próprio; `FeatureWorkspaceMetrics.titleSize` foi absorvido pelo token (era o único tamanho de título de página).
  _Alterado 2026-10-09 — era: "PageTypography.title = 40, label 11, data 11.5, micro 9.5". Motivo: recalibração de leitura e ergonomia desktop aprovada pelo operador; eliminação do contraste excessivo de 4:1 entre título de página e corpo de dados._

## 4. Geometria

- Escala de espaçamento: 4 · 8 · 12 · 16 · 20 · 24 · 32. Papéis: gap intra-item 8, gap entre linhas 12, respiro de seção 16, inset de painel 20, separação cabeçalho/body e respiro de cauda no scaffold 24 (pageGap), separação de blocos 32.
- Raio: controle 6, painel 10, base do notch 14, hairline 1 px.
- Densidade: linha compacta 28 px, linha padrão 36 px, item de menu bar 24 px, linha da sidebar 30 px (`Density.rowSidebar`). Painéis aninhados: cantos internos = raio do pai menos o inset (10 externo, 6 interno).
- Exceção geométrica é válida por requisito funcional ou de plataforma; registra papel, escopo e motivo.
- Reserva funcional local do seletor de entrada de Mídia (`UI/Media/MediaWorkspaceView.swift`): com arquivos, 30 pt no modo compacto (botão `small` 20 + trailing 8 + folga 2) e 32 pt no workspace; sem arquivo, 0 pt. Evita sobreposição do conteúdo com o botão de limpar; não é token nem exceção global.

### Exceções de plataforma registradas (2026-10-11)

- Offset de anel de foco (padding 1 pt ao redor do controle focável): `UI/MenuPanel/PanelLayout.swift`, `UI/MenuPanel/SystemSection.swift`. Motivo: o anel de 2 px com offset 1 px (§5) precisa de respiro fora dos limites do controle para não ser cortado.
- Evitar clipagem de hairline em grid/linhas (padding vertical 1 pt): `UI/MenuPanel/DiskSection.swift`, `UI/MenuPanel/FanControlSection.swift`. Motivo: o clipping de conteúdo pela plataforma cobre a hairline de 1 px das divisórias.
- Gutter compensando overlay de controle/scroll (padding 1 a 8 pt): `UI/MenuPanel/DiskSection.swift` (botão de ejeção), `UI/Media/MediaWorkspaceView.swift` (indicador de scroll). Motivo: overlays flutuantes da plataforma sobrepõem o conteúdo; o gutter compensa sem alterar a largura do item.
- Ajuste vertical de badge/tag em cápsula (padding vertical 1-2 pt): `UI/MenuPanel/DiskSection.swift`, `UI/MenuPanel/MenuPanelView.swift`, `UI/PortManager/PortManagerView.swift`, `UI/MenuPanel/PanelPortManagerView.swift`, `UI/AppUpdates/AppUpdatesListView.swift`, `UI/Settings/ShortcutsSettings.swift`. Motivo: a altura intrínseca de texto em cápsula varia por plataforma; o micro-padding centraliza o conteúdo no inset nominal.
- Densidade de linha de lista (padding vertical 1-2 pt): `UI/Cleaner/CleanerView.swift`, `UI/Uninstall/UninstallerView.swift`, `UI/KillProcess/KillProcessView.swift`, `UI/MenuPanel/MixerSection.swift`. Motivo: a métrica vertical nativa de linha adiciona espaço além do nominal de 28/36 px (§4); o ajuste restaura a densidade definida.
- Gutter de fill de hover em relação aos cantos do cartão (padding 3-4 pt): `UI/MenuPanel/MenuPanelView.swift`. Motivo: o raio do cartão exige recuo do fill de hover para que o arredondamento não vaze além do contorno.
- Raio do cartão interno do notch (18 pt, constante `NotchLayout.cardRadius`): `UI/Notch/NotchControlsView.swift`, `UI/Notch/NotchSystemView.swift`, `UI/Notch/NotchMusicView.swift`. Motivo: é a geometria interna do notch, definida pelas proporções físicas da ilha (DEC-017 §4); não é raio do design system e não entra na tabela §2.2.

## 5. Estados

- Estados operacionais distinguíveis por papel, não só por cor: ok, aviso, perigo, seleção, foco, desabilitado, progresso.
- Progresso usa `fg.secondary` + indicador de forma (spinner ou barra), nunca accent.
- Seleção: `selection.bg` + `fg.primary`; nunca só troca de cor de texto.
- Foco por teclado: anel `focus.ring` 2 px, offset 1 px, visível em qualquer superfície.

## 6. Matriz de contraste (WCAG 2.1 AA)

Método: luminância relativa sRGB (WCAG 2.1), texto 4.5:1, texto grande 3:1, não-texto/UI 3:1. Re-mediado em 2026-10-07 (script Python, mesma fórmula da medição de 2026-10-06) para os pares de accent neutro; demais pares mantêm a medição de 2026-10-06. Valores resolvidos sobre a superfície de uso.

### Tema escuro

| Par | FG | BG | Medido | Resultado |
|---|---|---|---|---|
| fg.primary / base | #F6F4EE | #17140F | 16.70 | PASS |
| fg.primary / raised | #F6F4EE | #211D15 | 15.26 | PASS |
| fg.secondary / raised | #AEABA4 | #211D15 | 7.32 | PASS |
| fg.secondary / base | #AAA8A2 | #17140F | 7.72 | PASS |
| fg.secondary / inset | #A7A5A0 | #0D0B08 | 7.99 | PASS |
| fg.tertiary / raised | #96938C | #211D15 | 5.49 | PASS |
| fg.tertiary / base | #928F8A | #17140F | 5.70 | PASS |
| fg.disabled / raised | #8C8882 | #211D15 | 4.76 | PASS (isento por WCAG 1.4.3; robustez) |
| accent.text / raised | #B8B2A9 | #211D15 | 7.98 | PASS (2026-10-07) |
| accent.text / base | #B8B2A9 | #17140F | 8.73 | PASS (2026-10-07) |
| accent.text / inset | #B8B2A9 | #0D0B08 | 9.34 | PASS (2026-10-07) |
| accent.solid / raised (não-texto) | #A8A199 | #211D15 | 6.57 | PASS, 3.0 exigido (2026-10-07) |
| accent.solid / base (não-texto) | #A8A199 | #17140F | 7.19 | PASS, 3.0 exigido (2026-10-07) |
| accent.solid / inset (não-texto) | #A8A199 | #0D0B08 | 7.70 | PASS, 3.0 exigido (2026-10-07) |
| focus.ring / raised | #A8A199 | #211D15 | 6.57 | PASS (3.0 exigido) (2026-10-07) |
| fg.primary / selection.bg s/ raised | #F6F4EE | #312D25 | 12.46 | PASS (2026-10-07) |
| fg.primary / selection.bg s/ base | #F6F4EE | #282520 | 13.88 | PASS (2026-10-07) |
| fg.primary / selection.bg s/ inset | #F6F4EE | #201D19 | 15.26 | PASS (2026-10-07) |
| status.ok / raised | #A3BF8F | #211D15 | 8.32 | PASS |
| status.ok / base | #A3BF8F | #17140F | 9.10 | PASS |
| status.warning / raised | #D89B4A | #211D15 | 6.96 | PASS |
| status.warning / base | #D89B4A | #17140F | 7.62 | PASS |
| status.danger / raised | #D08075 | #211D15 | 5.62 | PASS |
| status.danger / base | #D08075 | #17140F | 6.15 | PASS |

### Tema claro

| Par | FG | BG | Medido | Resultado |
|---|---|---|---|---|
| fg.primary / base | #201D17 | #F6F4EE | 15.28 | PASS |
| fg.primary / raised | #201D17 | #FBFAF6 | 16.09 | PASS |
| fg.secondary / raised | #5A554A | #FBFAF6 | 7.10 | PASS |
| fg.secondary / base | #5A554A | #F6F4EE | 6.74 | PASS |
| fg.tertiary / raised | #6F6D67 | #FBFAF6 | 4.95 | PASS |
| fg.tertiary / base | #6F6D67 | #F6F4EE | 4.70 | PASS |
| fg.disabled / raised | #8E8C86 | #FBFAF6 | 3.22 | PASS (isento por WCAG 1.4.3; robustez) |
| accent.text / raised | #5C564B | #FBFAF6 | 6.96 | PASS (2026-10-07) |
| accent.text / base | #5C564B | #F6F4EE | 6.61 | PASS (2026-10-07) |
| accent.text / inset | #5C564B | #ECE8DD | 5.94 | PASS (2026-10-07) |
| accent.solid / raised (não-texto) | #6E675C | #FBFAF6 | 5.35 | PASS, 3.0 exigido (2026-10-07) |
| accent.solid / base (não-texto) | #6E675C | #F6F4EE | 5.08 | PASS, 3.0 exigido (2026-10-07) |
| accent.solid / inset (não-texto) | #6E675C | #ECE8DD | 4.56 | PASS, 3.0 exigido (2026-10-07) |
| focus.ring / raised | #6E675C | #FBFAF6 | 5.35 | PASS (3.0 exigido) (2026-10-07) |
| fg.primary / selection.bg s/ raised | #201D17 | #EAE8E4 | 13.73 | PASS (2026-10-07) |
| fg.primary / selection.bg s/ base | #201D17 | #E6E3DC | 13.11 | PASS (2026-10-07) |
| fg.primary / selection.bg s/ inset | #201D17 | #DDD9CE | 11.92 | PASS (2026-10-07) |
| status.ok / raised | #607651 | #FBFAF6 | 4.78 | PASS |
| status.ok / base | #607651 | #F6F4EE | 4.54 | PASS |
| status.warning / raised | #8E672C | #FBFAF6 | 4.87 | PASS |
| status.warning / base | #8E672C | #F6F4EE | 4.63 | PASS |
| status.danger / raised | #A94F44 | #FBFAF6 | 5.17 | PASS |
| status.danger / base | #A94F44 | #F6F4EE | 4.91 | PASS |

Exceções e isenções registradas:

- `border.hairline` é divisor decorativo não informativo: isento de 3:1 (WCAG 1.4.11 cobre só o que é necessário para entender o conteúdo). Hierarquia não pode depender dele sozinho.
- `fg.disabled`: controles desabilitados são isentos por WCAG 1.4.3; mesmo assim os valores medem 3.2 ou mais.
- Nenhuma combinação aprovada reprova. Correções feitas na aprovação (2026-10-06): `fg.tertiary` claro subiu para 64%, `accent.text` claro escureceu para #84682C, `status.ok` e `status.warning` claros escureceram para #607651 e #8E672C.
- Re-medição 2026-10-07 (accent neutro): os 4 pares de accent e os pares de seleção passam sem ajuste adicional; `accent.text` claro fixado em #5C564B (mais escuro que o latão anterior, 4.5:1 sobrado em todas as superfícies).

## 7. Primitives canônicos

Contratos de anatomia, variantes, medidas (por token), estados, foco e acessibilidade. `N/A` marca o que não se aplica. Passivos não recebem tab stop nem foco artificial.

### HairlineDivider (passivo)

- Anatomia: linha 1 px `border.hairline`, largura total do conteúdo ou do inset.
- Variantes: full (atravessa o inset) e inset (alinha ao texto).
- Medidas: 1 px; sem margem própria, o espaçamento vem do contêiner (§4).
- Estados: N/A. Foco: N/A. Acessibilidade: decorativo, escondido de leitor de tela.

### SectionLabel (passivo)

Implementação equivalente: sectionTitle(_:) e hexaSectionLabel().

- Anatomia: texto `micro`, cor `accent.text` (taupe neutro desde 2026-10-07).
- Variantes: N/A.
- Medidas: sem margem própria; o respiro vem do contêiner (header de Form/Section: 8/4 local; header de painel: espaçamento do contêiner). _Alterado 2026-10-09 — era: respiro superior 16, inferior 2. Motivo: auditoria confirmou que nenhum consumidor entrega 16/2; o helper entrega anatomia (micro + accent.text + isHeader) e o espaçamento é do contêiner (ISSUE-064)._
- Estados: N/A. Foco: N/A. Acessibilidade: heading estrutural da seção.
- Justificativa do uso de accent: rótulo de seção usa o accent neutro de forma controlada (só este papel); não é ação nem status. O latão da marca não alimenta mais este papel.

### DataRow (contrato de referência, passivo ou interativo)

Não existe atualmente um tipo Swift DataRow. Linhas de métricas são composições de domínio; não se afirma adoção de um primitive inexistente.

- Anatomia: rótulo (`body`) à esquerda, valor (`data`) à direita, opcional chevron (14 px, `fg.tertiary`).
- Variantes: `plain` (passivo), `action` (interativo, com chevron), `accent` (valor em `accent.text`), `status` (valor em `status.*`).
- Medidas: altura 28 (compacta) ou 36 (padrão); padding horizontal = inset do painel (20); gap interno 12.
- Estados: normal; selecionado (`selection.bg` + `fg.primary`); desabilitado (`fg.disabled`); foco por teclado (anel padrão, §5); pressionado (reduz `surface.raised` contrast levemente, sem mudar altura).
- Foco e teclado (variante `action`): entra na tab chain, anel visível, Enter e Espaço ativam, rota por setas dentro do grupo.
- Acessibilidade: rótulo completo acessível a leitor de tela; valor com `data` anunciado junto do rótulo.

### PanelHeader (passivo)

Implementação equivalente: MenuPanelHeader.

- Anatomia: lockup da marca centralizado — glifo 28 px + wordmark (`display` 24) — no topo do painel, SEM slot de estado (o hash/versão saiu do painel na Fase 2); badge beta opcional alinhado à direita quando a build é pré-release.
- Medidas: altura do header 52; gap do lockup 12; sem borda inferior própria (a separação header/rail/conteúdo vem do respiro, §4).
- Estados: N/A. Foco: N/A. Acessibilidade: título da tela.
- _Alterado 2026-10-07 — era: "marca 18 px + wordmark (display 20) à esquerda; slot de estado (data 10.5, fg.tertiary) à direita". Motivo: redesign horizontal do MenuPanel (Fase 2): marca maior e centralizada por pedido do operador; exibição de hash/versão removida._

### HexaSegmentControl (interativo)

Segment control neutro para tabs de domínio (ex.: Controles/Monitor/Ferramentas, Recursos/Permissões). Código: `Sources/Hexa/UI/Components/HexaSegmentControl.swift`.

- Anatomia: N segmentos (`label`), iguais em largura, gap 4 (`Spacing.xs`), dentro de um contêiner. Aceita `Value: Hashable` (rótulo + valor) além do atalho por índice `Int`.
- Variantes: N/A (tamanho uniforme).
- Medidas: altura de linha compacta 28; raio de controle 6; padding horizontal interno 12.
- Estados: selecionado (`selection.bg` + `fg.primary` + borda informativa `accent.solid` 1.5 px, o mesmo recorte da `SettingsChoiceTile`; nunca só troca de cor de texto); não-selecionado (`fg.secondary`, sem fill e sem borda); desabilitado (`fg.disabled`, sem fill); sem fill de accent em nenhum segmento. Foco substitui a borda de seleção pelo anel `focus.ring`.
  _Alterado 2026-10-29 — era: selecionado só `selection.bg` + `fg.primary`. Motivo: `selection.bg` a 12% sobre `surface.inset` não distinguia o segmento ativo; a borda `accent.solid` 1.5 px (par já medido na §6) replica o recorte da tile de escolha._
- Foco e teclado: `FocusState` por segmento; anel `focus.ring` 2 px; setas esquerda/direita rotam dentro do grupo; desabilitado não recebe foco.
- Acessibilidade: `.isButton` + `.isSelected` no segmento ativo; rótulo anunciado.
- Rail vertical NÃO é variante deste primitive (2026-10-07, Fase 2): a rail de domínios do MenuPanel tem linhas de largura variável, ícone + rótulo e agrupamento em dois níveis (domínio/seção) — anatomia que diverge do segmento uniforme. Vive como composição local (`HexaDomainRail`, mesmo padrão neutro de seleção). Uma variante de eixo vertical neste primitive só se justifica com um segundo consumidor real (ex.: Ajustes).

### HexaStateTag (passivo)

Etiqueta de estado com dot à esquerda. Código: `Sources/Hexa/UI/Components/HexaStateTag.swift`.

- Anatomia: dot 6 px + texto (`label`), fundo neutro discreto (`surface.inset`).
- Variantes: `ok` / `warning` / `danger` (o dot carrega `status.*` correspondente).
- Medidas: altura 28 (linha compacta) ou menos; raio de controle 6; padding horizontal 8; gap dot-texto 8.
- Estados: N/A (o estado é o conteúdo). Foco: N/A (passivo, sem tab stop).
- Acessibilidade: dot é decorativo; o texto do estado é o rótulo anunciado. Texto sempre neutro (`fg.secondary`); a cor do estado vive só no dot.

### HexaDisclosure (interativo)

Disclosure/acordeão com animação contínua de altura e chevron rotacionando junto. Código: `Sources/Hexa/UI/Components/HexaDisclosure.swift`.

- Anatomia: linha de cabeçalho (rótulo do consumidor + chevron 90° rotacionado quando expandido) + conteúdo indentado (`disclosureIndent`, 25 pt).
- Variantes: N/A.
- Medidas: cabeçalho altura 28 (compacta); raio de controle 6; gap rótulo-chevron MÍNIMO 8 (o chevron fica ao fim da linha via `Spacer`; o gap real varia com a largura do rótulo); conteúdo com respiro superior 8.
- Estados: expandido/colapsado; chevron `fg.secondary`.
- Foco e teclado: cabeçalho na tab chain, anel `focus.ring` 2 px, Enter/Espaço ativam; valor anunciado expanded/collapsed.
- Animação: sutil em `easeInOut(duration: 0.2)` na rotação e expansão, sem bounce ou oscilação; a altura anima de forma contínua e previsível; com "reduce motion", sem animação (transição identidade).
- Acessibilidade: `.isButton` no cabeçalho; `accessibilityValue` reflete o estado.

Variações funcionais delimitadas:

- `CleanerView.groupRow`: cabeçalho próprio (chevron, checkbox e rótulo) em vez de `DisclosureGroup` nativo, com checkbox de seleção independente. Button envolvendo o label impediria separar selecionar o grupo de expandi-lo. Mantém fonte/cor hexa. Cada grupo fica em cartão leve (ver "Cartão leve dos grupos da Limpeza", 2026-10-18). Não isenta disclosure sem checkbox.
- `SystemSection.usageRow` e `memoryRows`: cabeçalho com barra, valor e expansão exclusiva por BreakdownKind. Preserva a anatomia de dado e demanda de amostragem, com foco visível e estado expandido/colapsado localizado.
- `PanelSection`: cabeçalho com edição/reset independentes e persistência de colapso; composição de domínio.
- `FeatureHubSettings.groupCard` (Ajustes > Recursos): `HexaDisclosure(indentsContent: false)`. O cabeçalho do grupo fica fora do cartão, como o da Ilha dinâmica, e o cartão tem a mesma margem do cartão da Ilha em vez de recuar 25 pt. Medidas, colapso e foco não mudam. Motivo: o recuo desalinhava os grupos abaixo da Ilha.
- Medidas de SF Symbols, gráficos, thumbnails, canvases e mockups em Ajustes são geometria gráfica ou de plataforma. Não isentam espaçamento/raio de controles comuns.
- Separadores em Menu/contextMenu continuam Divider nativo. Divisores de layout usam HairlineDivider.

Isenção registrada: `DisclosureHeaderRow` (`UI/SharedUI.swift`) é um primitive de disclosure animado PRÉ-existente ao `HexaDisclosure`, mantido pelos usos que já o consumiam antes da adoção: `UI/Settings/ShortcutsSettings.swift` e `UI/Media/MediaWorkspaceView.swift`. A isenção é delimitada a esses consumidores: uso novo de disclosure prefere `HexaDisclosure`.
_Alterado 2026-10-25 — era: `UI/Settings/ShortcutsSettings.swift`, `UI/Settings/MonitorPanelConfig.swift` e `UI/Media/MediaWorkspaceView.swift`. Motivo: `UI/Settings/MonitorPanelConfig.swift` foi removida como código morto no commit `b8a27cf`; restam dois consumidores no código._

Promoção: primitive novo só com dois consumidores reais ou transversalidade comprovada, comparando anatomia, variantes, medidas, estados, foco e acessibilidade antes. Composição local de domínio é legítima e não vira primitive por semelhança visual.

### HexaActionButtonStyle (interativo)

- Consumidores reais: ações em Ajustes/Suporte, cartão de permissão, operações nas ferramentas e ações no painel.
- Anatomia: label do consumidor, padding horizontal 12, altura mínima 28 em mini/small e 36 em regular/large, raio de controle 6.
- Variantes: `.secondary` (padrão) e `.primary` (a ação de maior peso da superfície). Nada de accent de sistema: as duas variantes são neutras.
- Estados (código vigente; corrige a entry anterior que dizia "normal selection.bg" — isso é o estado normal da variante `.primary`): normal `surface.inset` (secondary) ou `selection.bg` (primary); hover `selection.bg` a 70% (secondary); pressionado `selection.bg`; desabilitado `surface.inset` a 50% + `fg.disabled`; foco com `focus.ring` 2 px, offset 1.
- Teclado e acessibilidade: preserva a semântica do Button e seus atalhos; label acessível fornecido pelo consumidor. Seleção não é estado deste botão de ação.

### HexaCard e HexaSection (passivos) — o cartão único

- **Regra:** toda tela que desenha um cartão usa o MESMO desenho: fundo `surface.raised`, raio de painel 10, respiro 16, largura cheia da coluna. Sem contorno. O título da seção NUNCA vive dentro do cartão.
- **HexaCard** (`UI/Components/HexaCard.swift`): componente de página; estica a largura e aplica o desenho. Passivo: N/A foco/tab.
- **HexaSection** (`UI/Components/HexaCard.swift`): SectionLabel (micro caixa-alta, `accent.text`) FORA do cartão, gap título→cartão 8 (`Spacing.s`), `HexaCard` embaixo. É o padrão da tela de Telas; composição de seção de página SEMPRE por ele.
- **Contorno:** NENHUM por padrão. Exceção funcional: com "Aumentar contraste" do macOS, a hairline volta (acessibilidade; o desenho vive em `hexaCardSurface(increaseContrast:)`).
- **`panelCard()`/`HexaSectionCardModifier`** (painel da menu bar): o MESMO desenho (respiro 16, raio 10, sem contorno + exceção de contraste), sem o stretch de largura; no notch, mantém `NotchControlSurface` intacto. Consumidores de `panelCard()` não mudam de API.
- Pares de contraste: os de fg.*/raised já medidos na §6. Hairline de contraste aumentado é a isenção já registrada.

### Sidebar da janela operacional: HexaSidebarRow e HexaSidebarSearchField

A sidebar atual é composta em `FeatureWorkspaceView`; não há um host `HexaSidebar`. Módulos e destinos de sistema, incluindo as páginas de Ajustes, compartilham a mesma sidebar e a mesma janela (`FeatureWorkspaceWindow`). A composição tem largura 220, fundo `surface.raised`, hairline à direita, lockup da marca e busca fixos no topo, uma lista `OverlayScrollView` reta de `HexaSidebarRow` para as funcionalidades (sem cabeçalho de grupo), e a seção `Preferências` (`systemSection`: Geral, Barra de menus, Recursos, Atalhos, Avançado, Sobre) fixa na base abaixo de um `HairlineDivider`.
- **HexaSidebarRow**: hover clareia só o texto (`fg.secondary` → `fg.primary`), sem fill ou crescimento. Seleção: `selection.bg` + `fg.primary` + dot de 5 px. A linha usa `body`, altura mínima de 30 pt (`HexaTheme.Density.rowSidebar`), padding horizontal 12 e raio de controle 6. O primitive aceita anel `focus.ring` de 2 px quando o consumidor fornece `isFocused`; a composição atual usa o valor padrão, sem afirmar foco visual observado. Rótulo anunciado e `.isSelected` na linha selecionada. _Alterado 2026-10-14 — era: 28 pt (`Density.rowCompact`). Motivo: teste visual de densidade pedido pelo operador; token próprio da sidebar para não alterar `rowCompact` dos demais componentes. Pendente de aprovação visual._
- **HexaSidebarSearchField**: lupa e campo plain em `body`; Esc limpa e há botão de limpar quando o texto não está vazio. Fundo `surface.inset`, raio de controle 6. O primitive aceita binding opcional de `FocusState`; a composição atual passa a busca e o placeholder, sem binding de foco.
- **Módulos na sidebar (contrato de 2026-10-14, atualizado em 2026-10-18):** a lista tem dois tipos de linha. Linha simples representa um recurso. Linha de módulo agrupa de dois a quatro recursos e mostra um controle segmentado no topo da coluna de conteúdo (`pinned`), no mesmo padrão das abas da Ilha dinâmica e das métricas do Monitor. O título da linha de módulo é fixo; o subtítulo da página muda conforme o membro ativo. Módulos: "Manutenção" (cleaner, maintenanceTasks, uninstaller e appUpdates), "Processos e portas" (killProcess e portManager), "Captura de tela e texto" (screenshot e screenOCR, com a página de OCR) e "Energia e tela" (keepAwake e brightness). Monitor (métricas, Dispositivos conectados e Controle das ventoinhas) e Dynamic Island mantêm suas linhas e abas no segmento do cabeçalho (`NotchSettingsTab` na Ilha dinâmica; métricas no Monitor, que ficam desabilitadas quando o modo Ajustes do Monitor está aberto).
  - Cabeçalho do módulo (coluna de conteúdo): segmento de membros no topo (`pinned`), um segmento por membro disponível, na ordem do módulo (em "Captura de tela e texto", os segmentos são "Captura de tela" e "Texto da tela (OCR)"). O título do módulo é fixo; o subtítulo segue o membro ativo e o modo (Operação ou Ajustes). Módulos e recursos com página de configuração própria (Monitor, Mixer, Limpeza, Atualizações, Captura de tela e OCR) exibem no canto direito do cabeçalho (`headerTrailing`) o botão `settingsToggle` (ícone de engrenagem + rótulo "Ajustes", ou segmento Operação/Ajustes quando Limpeza ou Atualizações aparecem como linha simples sem módulo). Trocar entre membros que suportam Ajustes dentro do mesmo módulo preserva o modo Ajustes aberto; trocar para membro sem Ajustes, de módulo ou de recurso volta à operação. "Processos e portas" exibe o botão de atualizar (`arrow.clockwise`) no cabeçalho tanto em Processos quanto em Portas.
  - Membro desligado em Recursos some do controle segmentado. Módulo com um único membro disponível se comporta como linha simples, sem controle segmentado. Módulo sem nenhum membro disponível fica oculto.
  - O módulo lembra o último membro aberto, só em memória (mesmo comportamento da aba da Ilha dinâmica). Clicar na linha abre o membro lembrado ou, na falta dele, o primeiro disponível.
  - Cabeçalho de grupo: REMOVIDO (2026-10-25). A lista de funcionalidades é reta, sem subdivisão rotulada. Os grupos do catálogo (`FeatureGroup`: som, energia e ambiente, ferramentas, ilha dinâmica, monitor) ordenam as linhas mas não as agrupam visualmente; a seção `Preferências` no rodapé mantém seu `SectionLabel`, por separar tipos diferentes de destino (funcionalidades vs. destino de sistema). _Alterado 2026-10-25 — era: "Cabeçalho de grupo: exibido só quando o grupo tem duas ou mais linhas visíveis (`entries.count > 1`). Grupo com uma única linha (como Dynamic Island, Áudio e Energia e ambiente quando colapsado em módulo) não exibe `SectionLabel`." Motivo: pedido do operador; o rótulo ocupava a mesma coluna das linhas clicáveis (20 pt em ambos os casos) e competia com elas, sem hover nem clique, e sua fronteira não era fiel (Dynamic Island, grupo de uma linha, aparecia dentro do bloco "Utilitários"). ISSUE-770._
  - Espaço vertical entre os itens da lista de funcionalidades: `Spacing.xs` (4 pt), antes 2 pt em valor literal. A lista de sistema (Geral, Barra de menus, Recursos, Atalhos, Avançado, Sobre) mantém 2 pt. Ponto aberto para a revisão visual do operador: aplicar 4 pt também ao sistema ou manter a diferença. A altura da linha continua 30 pt (`HexaTheme.Density.rowSidebar`), como registrado acima.
  - Busca encontra os membros dos módulos e abre o membro que casou com o termo.
  - Esta entrada substitui, para a sidebar, a frase de 2026-10-07 "sidebar (Lista plana de páginas)" em §8. A frase original não foi reescrita e fica como registro histórico.
  - Status: pendente de aprovação visual do operador. Esta entrada não declara a aparência aprovada.

### HexaScreenScaffold

- **HexaScreenScaffold** (`UI/Components/HexaScreenScaffold.swift`): scaffold das telas da coluna direita. Anatomia: título (`featureTitle`) e subtítulo opcional (`featureSubtitle`) com respiro lateral 32; slots opcionais para ação no cabeçalho e conteúdo fixo (ex.: segmento do Monitor); slot de conteúdo ocupa o restante da coluna.
- O scaffold separa o cabeçalho do conteúdo por `Spacing.pageGap` (24 pt). Com `scrolls: true`, ele próprio envolve o conteúdo em `OverlayScrollView` e acrescenta 24 pt ao fim do corpo rolável. Com `scrolls: false`, o consumidor entrega a rolagem ou o conteúdo direto. As telas da janela operacional usam o scaffold na coluna direita; a composição da sidebar fica em `FeatureWorkspaceView`.
- Estados: N/A. Foco: N/A (passivo). Acessibilidade: título com `.isHeader`.

### HexaIconButtonStyle e HexaIconButton (interativos)

- O ícone-só-botão anda SEMPRE em caixa própria. Anatomia: ícone centralizado em quadrado — `.regular`: 28 pt com ícone 14 (`HexaIconMetrics.label`); `.small`: 20 pt com ícone 12 (`HexaIconMetrics.small`). Raio de controle 6.
- Estados: normal `surface.inset`; hover `selection.bg` a 70%; pressionado `selection.bg`; desabilitado inset a 50% + `fg.disabled`; foco anel 2 px, offset 1. `HexaIconButton` exige rótulo de acessibilidade (`accessibilityLabel`).
- `iconTint: Color?` (2026-10-08): parâmetro opcional do estilo e do componente para botões de ícone com ESTADO de consumo — o chamador passa o token (`status.ok`/`status.warning`/`status.danger`) e ele tintA só o ícone; o container segue nos tokens padrão. Default nil preserva o comportamento existente. Nunca usar para accent de seleção (a seleção é o `selection.bg` do container).
- Ícone que é só conteúdo de linha (checkbox, rótulo, chevron de linha) NÃO recebe caixa: é `HexaIcons.image` direto na linha.

### HexaAccessButton (interativo)

- Ação de acesso: pedir permissão do sistema ou abrir Ajustes do sistema — qualquer ação que SAI do hexa para uma superfície do sistema. Um único desenho: ícone do assunto (`fg.secondary`) + título (`label`) + glifo de saída `arrow.up.right` (`fg.tertiary`, 12), sobre `HexaActionButtonStyle` (estados, foco e teclado do botão de ação). Respeita `controlSize` do entorno.
- Consumidores reais: `PermissionRow` (pedir permissão, abrir Ajustes) e páginas de permissão do hub.

### HexaListItem (interativo)

- Item de lista para listas de conteúdo (apps, processos, dispositivos): linha inteira clicável — ícone opcional (conteúdo da linha, sem caixa), título (`body`), legenda opcional (`label`, `fg.secondary`) e slot à direita. Altura mínima 36, padding horizontal 12, raio de controle 6.
- Estados: hover SÓ clareia o texto (mesma lei da sidebar); seleção `selection.bg`; `.isSelected` anunciado. Foco via `.focused` do consumidor quando a lista é navegável.

### HexaStatusNote (passivo)
- **HexaStatusNote** (`UI/Components/HexaStatusNote.swift`): nota inline de status, o bloco único de mensagem de estado em painéis e ajustes. Anatomia: texto curto em `label` com quebra vertical livre (`fixedSize` horizontal falso, vertical verdadeiro) na cor do tom. Tons: `warning` (`statusWarning`) e `neutral` (`fgSecondary`), os únicos observados em consumidores reais. Ícone opcional (semântico, `Label` + `hexaIcon`) quando a nota é banner. Sem fundo, borda ou respiro próprio; condição de exibição, limite de linhas, padding e cartão (`panelCard`) ficam no call site.
### HexaBusyState (passivo)
- **HexaBusyState** (`UI/Components/HexaBusyState.swift`): estado ocupado/carregando centralizado, o bloco único de espera de página e painel. Anatomia: spinner centrado vertical com `Spacer` nos dois lados e `frame(maxWidth: .infinity)`, mensagem opcional em `body` (`fgSecondary`), detalhe opcional em `label` (`fgTertiary`), ação opcional (ex.: cancelar durante scan) e slot `accessory` para conteúdo extra entre mensagem e ação. Variantes: `workspace` (spinner `.large`, respiro `Spacing.l`, altura mínima 320) e `compact` (spinner `.small`, respiro `Spacing.s`, sem altura mínima), as únicas observadas. A moldura externa (altura fixa, preenchimento dos eixos) e a condição de exibição ficam no call site.
- **Uso padronizado (2026-11-07):** toda espera de primeira carga sem dado usa `HexaBusyState` com mensagem: `l10n.s.loadingMessage` ("Carregando…") ou uma chave específica já existente. Condição: leitura pendente e nenhum dado exibido. Com dado já na tela, o conteúdo permanece e o refresh usa indicador discreto inline. Ação do usuário, vazio confirmado e erro não são espera. Todo carregamento termina em conteúdo, vazio confirmado ou erro visível. Referência: `FanControlCardContent` (`UI/MenuPanel/FanControlSection.swift`).

### HexaResultsFooter (interativo)
- **HexaResultsFooter** (`UI/Components/HexaResultsFooter.swift`): rodapé de resultados de telas de seleção (Cleaner, Desinstalador do workspace). Anatomia: HStack com slot esquerdo de metadados (`@ViewBuilder`, formato da contagem é do domínio), `Spacer`, botão secundário opcional plain (reset/cancelar) e botão primário `HexaActionButtonStyle` (variante padrão, desabilitável), padding do rodapé parametrizável (padrão `Spacing.l`). A divisória acima do rodapé é do contêiner (`HairlineDivider`); o primitive não a inclui.
- **HexaCaptionText** (`UI/Components/HexaCaptionText.swift`): legenda de apoio multi-linha solta dentro de `HexaSection`, via modifier `Text.hexaCaption()`. Anatomia: fonte `label`, cor `fgSecondary`, quebra vertical livre (`fixedSize` horizontal falso, vertical verdadeiro). Sem parâmetros; inset de alinhamento com o texto da row (`settingsRowTextInset`), condição de exibição e respiros ficam no call site.
### HexaKeyValueRow (passivo)
- **HexaKeyValueRow** (`UI/Components/HexaKeyValueRow.swift`): linha de leitura label + valor com valor à direita. Anatomia: HStack com `Spacing.s`, label em `body` (`fgSecondary`), `Spacer(minLength: Spacing.s)`, valor em `data` (`fgPrimary`) alinhado à direita e slot `trailing` opcional para controle inline (ex.: ocultar item). Valor `String?`: `nil` omite só o `Text` (leitura indisponível) e mantém o label. Ícones, legendas, animação de valor (`numericText`) e a condição de exibição da linha inteira ficam no call site.
- Estados: primário e secundário herdam disabled do consumidor; `primaryControlSize` existe porque o Cleaner usa `.large` e o Desinstalador `.regular` (padrão).
- Foco e teclado: semântica nativa de Button preservada. Acessibilidade: rótulos são os textos dos botões, fornecidos pelo consumidor.
### HexaPanelHeader (interativo)
- **HexaPanelHeader** (`UI/Components/HexaPanelHeader.swift`): cabeçalho de painel embutido (Port Manager, App Updates, Desinstalador, Capturas recentes). Anatomia: HStack com `Spacing.s`, título com ícone semântico (`Label` + `hexaIcon`, papel `body`), `Spacer` e slot `actions` à direita para os botões do consumidor (tipicamente `HexaIconButton` variante `small`, cada um com `.help()` e estado próprio). O primitive compõe, não reimplementa botões; quais ações aparecem, estados (fechamento opcional, disabled por lista vazia) e `.help()` ficam no call site. Distinto de `HexaBreadcrumbHeader` (detail com voltar), que não é afetado.

### Regras de composição (grid e ícones)

- **Grid:** células SEMPRE centralizadas (ícone e rótulo centrados na célula), qualquer conteúdo, qualquer largura — sem célula com texto alinhado à esquerda dentro de grid de cartões.
- **Ícone e cartão:** ícone como conteúdo de linha não recebe caixa; ícone-só-botão recebe (HexaIconButton); cartão não contém título de seção.

### Padrão de botões por papel (2026-10-13)

Cada botão usa o componente do papel que cumpre na superfície. Nenhum componente aceita todas as variações.

| Papel | Componente | Geometria | Uso |
|---|---|---|---|
| Ação neutra | `HexaActionButtonStyle` `.secondary` | altura 36 regular e 28 mini/small; raio 6; padding horizontal 12 | ações em linha, rodapés e painéis |
| Ação principal | `HexaActionButtonStyle` `.primary` | igual à ação neutra | a ação de maior peso da superfície; no máximo uma por superfície |
| Atalho | `ShortcutRecorderButton` | igual à ação neutra; largura definida pelo consumidor | gravar uma combinação de teclas |
| Ícone | `HexaIconButton` | quadrado 28 regular e 20 small; raio 6 | só ícone, com rótulo de acessibilidade |
| Acesso ao sistema | `HexaAccessButton` | igual à ação neutra | ação que sai do hexa para uma superfície do sistema |
| Texto e link | nativo (`.plain`, `.borderless`, `.link`) | sem caixa | dentro de listas e conteúdo |

Regras:

- Controles lado a lado na mesma linha têm a mesma altura e o mesmo raio. Linha compacta usa 28; linha padrão, 36.
- O atalho segue os estados da ação neutra: normal `surface.inset`; hover `selection.bg` a 70% (só no fundo); pressionado `selection.bg`; desabilitado `surface.inset` a 50% com texto a 50% de `fg.primary` (valor de `fg.disabled`); foco com anel `focus.ring` de 2 px e 1 px de respiro. Texto no papel `label`.
- Enquanto grava, o atalho mostra o aviso no mesmo casco e mantém o anel de foco.
- Destaque nativo (`.borderedProminent`) e controles de sistema em superfícies flutuantes (HUD, prévia de captura) ficam fora do padrão enquanto a superfície for nativa.
- Fora deste padrão nesta fase: `NotchButtonStyle` (família própria do notch), `KeepAwakeChipStyle` (chip local do painel) e os botões nativos de texto e link.
- Adoção por superfície. O padrão não autoriza reescrita global: mudar `HexaActionButtonStyle` exige inspecionar todos os consumidores (75 pontos de uso).

## 8. Revisão visual (matriz proporcional)

Mudança que afeta aparência ou usabilidade inspeciona:

| Dimensão | Verificação |
|---|---|
| Estado e tema | normal, foco por teclado, vazio, progresso, erro, seleção; escuro E claro |
| Conteúdo | texto longo, quebra, overflow |
| Contexto | menu bar (16 px), painel, notch; input teclado e mouse |

`N/A` registrado com motivo. Gate estático verde não declara equivalência visual.

Registro por superfície:

- **Janela operacional, Feature Hub, Brilho e páginas do notch (2026-10-11):** revisão estrutural do código final. A sidebar e as páginas de Ajustes compartilham a janela; grupos do Hub usam SectionLabel fora do cartão; o toggle de Brilho limita monitores e deixa a luz do teclado independente; o scroll vertical da página no `NotchView` usa `notchScrollEdgeFade`; letras/fila abertas recebem viewport interno pelo budget disponível, sem o scroll externo. Gates registrados pelo orquestrador: `swift build` de todos os alvos (exit 0, 9,49 segundos), `swift test` (115 testes, zero falhas), `./build.sh` com bundle e assinatura local (exit 0) e `git diff HEAD --check` (exit 0). CUA visual indisponível por `Sky native pipe startup failed`; nenhum render, foco, contraste, estado de hardware ou smoke visual é declarado aprovado. Pendentes: render e foco em contexto real, revisão de cores/temas e smoke pelo operador.

- **MenuPanel horizontal (Fase 2, 2026-10-07):** estados inspecionados na estrutura e no código: normal, seleção (rail: `selection.bg` + `fg.primary`), hover (fill discreto), foco por teclado (anel `focus.ring`), desabilitado (N/A na rail: nenhum item desabilitável). Temas: escuro e claro via tokens dinâmicos. Conteúdo: seções longas rolam dentro da área fixa (tamanho do painel estável); título longo de seção truncado com `lineLimit(1)` + `help`. Contexto: painel da menu bar (560x420, rail + conteúdo); contexto notch N/A nesta fase (a navegação embutida do notch permanece na forma horizontal anterior); menu bar coberta pela revisão do `menuBarSize` (§1.1). Resíduo: render real do popover não inspecionado neste ambiente (ver §9).
- **Ajustes (Fase 3 do redesign minimalista, 2026-10-07):** superfícies: sidebar (Lista plana de páginas), página Recursos (hub + portal de permissões), Geral, Monitor, Notch (+ editores), Screenshot, App Updates, Atalhos, Avançado, Sobre, Notas, Suporte. Estados inspecionados na estrutura e no código: normal, seleção (sidebar e escolhas com `selection.bg` + `fg.primary`, lista com `.tint(accentSolid)`), foco por teclado (anel `focus.ring` no destaque de chegada da seção e nos primitives), hover (fill `fg.primary` 4-5%), desabilitado (`fg.disabled`/opacidade), progresso (barra e rótulos em `fg.secondary`), status (dot `status.*` + texto neutro via `HexaStateTag`). Temas: escuro e claro via tokens dinâmicos (nenhuma cor fixa de UI nova). Conteúdo: linhas de hub e listas de apps truncam com `lineLimit(1)`; legendas com `fixedSize` vertical; rótulos longos de segmento truncam com `lineLimit(1)`. Contexto: janela de Ajustes (sidebar 198-240 + detalhe); contexto menu bar e notch N/A nesta fase (nenhum componente desta fase vive fora da janela). Resíduos: render real em app rodando não inspecionado neste ambiente; tiles de identidade de módulo do editor do notch (`settingsTint`) e as cores configuráveis de barra de uso permanecem paleta própria de conteúdo (mesma natureza de `PanelMetricColor`), não colapsadas nos `status.*`; thumbnails de desktop e mockups do notch usam literais porque as cores são o retratado.
- **Chrome do editor de screenshot (isenção nominada, 2026-10-10):** as barras flutuantes, scrims e sombras do chrome do editor de captura em `Sources/Hexa/UI/Screenshot/ScreenshotEditorView.swift` (sites verificados: ~401-420, 541, 612, 796-1062, 1551; o de 1551 é a cor padrão de anotação na prévia, conteúdo e não chrome) e `ScreenshotBackdropPopover.swift:217` usam `.black.opacity(...)` e sombras literais em vez de tokens. Justificativa: canvas de desenho com pan próprio — o chrome flutua sobre conteúdo arbitrário do usuário (a captura real), e nenhum token de superfície do app descreve esse fundo; as sombras literais garantem a separação do chrome sobre qualquer imagem. Isenção de contraste: o chrome flutuante não forma par FG/BG estável mensurável (o fundo é a captura sob ele); a legibilidade decorre das sombras e dos scrims, não de um par auditado. Escopo delimitado ao editor de screenshot e ao seu popover de backdrop: não se estende a outros papéis, temas ou superfícies, e não cobre textos e controles comuns de UI fora do chrome flutuante. Valores inalterados; registro de isenção, não de nova cor.

## 9. Adoção e cobertura

- Inventário original (pré-adoção): `Sources/Hexa/UI/` inteiro operava em SF Pro/system, sem tokens. Marcado NÃO AVALIADO para adoção.
- **2026-10-06, adoção completa (Fase 1):** `Sources/Hexa/UI/` (10 subpastas: AppUpdates, Cleaner, KillProcess, Media, MenuPanel, Notch, PortManager, Screenshot, Settings, Uninstall) + `Sources/Hexa/App/` adotados: ~981 sites de papel tipográfico e cor mapeados para os tokens; fontes OFL embutidas com registro no launch; marca Conceito A na menu bar e nos headers. Provas: auditoria independente (14 pontos, sem erro novo vs. baseline; zero literal proibido; localização, Services e sob demanda intactos) + probe CoreText dos nomes PostScript. Notch preservou tamanhos dinâmicos exatos (DEC-007).
- **Dívida estética ACEITA (com justificativa):** ~30 literais residenciais em `SharedUI.swift`, `Theme.swift` e `NotchView.swift` (tints de vidro do painel, corpo físico do notch, sombras e backdrops) sem papel semântico na §2.2; adoção exigiria registrar token novo antes. `PanelMetricColor` (paleta de dataviz) não colapsada nos 3 `status.*`: preserva informação de gráfico. Pendente de prova: render visual no app rodando (cauda de build de `Services/` resolvida em 2026-10-06; prova segue para o fechamento, M8) e aplicação do `AppIcon.icns` ao Dock (`build.sh` já copia o icns para o bundle; prova visual no Dock pendente do operador).
- Baseline consumível: cópia bulk da Fase 3, sem pack.
- A UI nova nasce nos tokens dentro das slices M5-M8 do roadmap; não existe adoção posterior a planejar, e nenhuma superfície muda comportamento.
- **2026-10-07, fundação accent neutro (Fase 1 do redesign minimalista):** papéis de UI `accent.solid`, `accent.text`, `focus.ring`, `selection.bg` remapeados para taupe neutro (#A8A199/#B8B2A9 escuro, #6E675C/#5C564B claro); latão reservado à marca via tokens `brand.solid`/`brand.text` (`BrandMark` e wordmark religados). Matriz §6 re-medida (todos PASS). Primitives novos registrados em §7: `HexaSegmentControl`, `HexaStateTag`, `HexaDisclosure` (em `Sources/Hexa/UI/Components/`), prontos para adoção pelo redesign do MenuPanel e dos Ajustes. Tipografia: papéis existentes (`body`/`label`/`data`/`micro`) cobrem as superfícies previstas; nenhum papel novo necessário. Consumidores existentes não mudam de nome de token, só de valor (adoção silenciosa e imediata nas superfícies atuais).
- **2026-10-07, painel horizontal com rail (Fase 2 do redesign minimalista):** `MenuPanel` reestruturado: painel 560x420 de dimensões ESTÁVEIS (conteúdo rola; trocar domínio/seção/opção não redimensiona o popover), rail vertical de domínios à esquerda (`HexaDomainRail`, seleção neutra) com seções do domínio ativo em ordem alfabética pelo nome exibido, conteúdo do domínio à direita, header PanelHeader novo (lockup centralizado 28/24, sem hash/versão). Fresta de fundo resolvida: a superfície de vidro (`PanelGlassSurface`) subiu para a raiz do conteúdo do popover, cobrindo o balão inteiro com a safe area no escopo. Ícones de domínios e seções trocados caso a caso (conjunto próprio, DEC-011), estados por `fg.*`, sem cor de accent em ícone. Marca na menu bar ampliada (~10%, §1.1). Provas: `swift build` (todos os alvos), `swift test` (42/42), `git diff HEAD --check`. Pendente de prova: render real do popover em app rodando (operador).
- **2026-10-07, redesign dos Ajustes (Fase 3 do redesign minimalista):** superfície `UI/Settings/` adotada. Primeiro consumidor real dos primitives da Fase 1: tabs de página usam `HexaSegmentControl` (Recursos/Permissões; tabs do notch; seletor de ferramenta de captura), etiquetas de status usam `HexaStateTag` (permissões, atualizações, badges beta/experimental), e todos os `DisclosureGroup` da superfície deram lugar a `HexaDisclosure` (grupos do hub, lista de apps, exclusões de disco, opções extras), com a animação contínua do primitive. Sidebar achatada e determinística: "Geral" primeiro, "Recursos" segundo, demais páginas em ordem alfabética pelo nome exibido; seleção da lista em accent taupe (`.tint(accentSolid)`), sem azul de sistema; seções com cabeçalho recolhível removidas junto com os agrupamentos "Essenciais/Utilitários/Gestão de apps". Esquemas de instalação rápida removidos do hub: pacotes (presets), "Instalar tudo"/"Desinstalar tudo"; o toggle individual é a única via. `HexaStateTag` ajustado para abraçar o conteúdo (sem largura infinita), mantendo anatomia e medidas do contrato — sem consumidor anterior. Tipografia: papel base `body` aplicado à raiz de cada página e a `SettingsRow`; pesos custom (`hexaManrope(size:)`) de uso fixo mapeados para papéis; excesso de peso limitado a 600. Accent de sistema (`Color.accentColor`) eliminado da superfície em seleções, bordas, ícones e destaque de chegada de seção. Provas: `swift build` (todos os alvos), `swift test` (42/42), `git diff HEAD --check`. Pendente de prova: render real em app rodando (operador). Nota: escolhas de opção dentro de linha (frequência, °C/°F, atraso) permanecem `Picker` segmentado do sistema (controle, não tab).
- **Cartão de permissão (Fase 3 do redesign minimalista, 2026-10-07):** `UI/PermissionGuideOverlay.swift` (NSPanel flutuante próprio, largura 320) redesenhado com anatomia autoral: título `heading` + fechamento `xmark` (`fg.tertiary`, foco com `selection.bg`/`focus.ring`), estado via `HexaStateTag` (`ok` concedido) e, pendente, etiqueta equivalente em `surface.inset` com dot `fg.secondary` pulsante (progresso = forma + neutro, §5; sem accent nem azul); instrução em uma linha `body` (`fg.primary`) entre duas margens `label` (`fg.secondary`), sem bullets nem numeração; permissão em pauta como `data` em nicho `surface.inset`; ações ("Recomeçar", "Reabrir para aplicar") em botão neutro (`selection.bg` + `fg.primary`, anel `focus.ring`), sem `borderedProminent`. Dica de entrada stale em `label`/`fg.tertiary`, sem caixa colorida. Raios e espaçamento por token (painel 10, controle 6); sem `Color.accentColor` nem peso tipográfico fora de papel. Animações de estado respeitam reduce motion. Estados inspecionados na estrutura e no código: pendente (dot pulsante), stale (dica + Recomeçar), concedido (`HexaStateTag` ok; acessibilidade: agendado 1.6 s de saída), foco por teclado nos dois botões e no fechamento; escuro e claro via tokens dinâmicos. Contexto: card flutuante acima do System Settings; contexto painel/menu bar/notch N/A (a superfície não vive nelas). Contrato de apresentação (largura 320, non-activating, canJoinAllSpaces) preservado; lógica de detecção intocada. Strings reutilizadas; nenhuma string nova. Resíduos: render real do painel flutuante em app rodando não inspecionado neste ambiente (ver §9).
- **2026-10-07, cartão de permissão (Fase 3 do redesign minimalista):** `UI/PermissionGuideOverlay.swift` adotado: primeiro consumidor externo aos Ajustes do `HexaStateTag` (estado concedido) e de botão neutro `selection.bg` + `fg.primary` com anel `focus.ring` (padrão posteriormente consolidado em HexaActionButtonStyle na correção pré-smoke). Progresso por dot `fg.secondary` pulsante (§5). Provas: `swift build` (todos os alvos), `swift test` (42/42), `git diff HEAD --check`. Pendente de prova: render real do painel flutuante em app rodando (operador).
- **2026-10-07, Fan Control sai do beta (Fase 4 do redesign minimalista):** `UI/MenuPanel/FanControlSection.swift` e `FanControlCurveEditor.swift` endurecidos sem redesenho: o badge beta (que ainda consumia `Color.accentColor`, azul de sistema) foi removido do título da seção; mensagens de estado/erro passaram de `Color.red`/`Color.secondary` para `status.danger`/`fg.secondary`; valores (RPM atual e alvo, % do modo manual, temperaturas e níveis dos pontos da curva) migraram para o papel `data` mono tabular; o slider do modo manual ganhou `accessibilityLabel` e `accessibilityValue`. Estados inspecionados na estrutura e no código: normal (leitura do sistema), seleção (segmento manual/curva do Picker nativo), progresso (`ProgressView` + controles desabilitados), erro (`status.danger` nas mensagens: já controlado, hardware sem suporte, helper indisponível, falha de controle), parada de segurança (`safetyStopped`/`temperatureUnavailable` em `status.warning`), vazio (sem fans: linhas de fallback da menu bar ou mensagem). Temas: escuro e claro via tokens dinâmicos. Contexto: painel da menu bar (seção dentro do card); janela N/A; rota embutida do notch existe no `MenuPanelView` e exige revisão visual quando habilitada. Provas: auditoria do caminho de escrita SMC (alvos limitados à faixa reportada pelo sensor via `coolingTargetRPM`, validação de curva rejeita faixa/monotonia/NaN, falha solicita devolução ao controle automático do sistema, helper watchdog + teste unitário de validação; recuperação física não foi comprovada), `swift build` (todos os alvos), `swift test`, `git diff HEAD --check`. Pendente de prova: render real do painel e validação em hardware real pelo operador.
- **2026-10-08, varredura de literais de cor fora de token:** alinhamento de resíduos de sistema que restavam no chrome após a Fase 1: estados de conclusão/erro/atenção em `.green`/`.orange` (doneState do Uninstaller em Ajustes e painel, cards de erro do Media, erro do seletor de ferramentas de captura, legenda de atenção do MenuPanel, ícone de alternância de display no BrightnessSection) migraram para `status.ok`/`status.warning`/`fg.secondary` (par fg.secondary/inset e status.*/raised já aprovados na §6); placeholder de miniatura de capturas recentes (`Color.black.opacity(0.13)`) migrou para `surface.inset` (papel de campo/nicho); `Color.accentColor` (azul de sistema) eliminado dos HUDs em `Services/QuickTools` (`QuickToolHUD`, `QRResultController`, chip de seleção de `ScreenshotSelectionController`): foreground em `accent.text`, fill/anel de seleção e traço de progresso em `accent.solid` (papéis registrados). Sem token novo e sem mudança de comportamento. Permanecem fora do recorte, com justificativa: dots de pressão de memória (`MenuBarRenderer` e preview fiel em `MenuBarMetricsPreview`, `.systemGreen/.yellow/.red` espelhados renderer↔preview: retratado/dataviz, mesma família `PanelMetricColor`); mockup da menu bar em `MonitorSettings` (fundo preto fixo = o retratado, menu bar sempre escura); Notch como fatia própria (corpo físico preto, whites sobre preto, `Color.mint`, `Color.purple` de tint de agente, `Color.secondary`: matriz de contraste própria na §8, mudança em lote exige slice gated); tints de vidro/knob com blend mode e sombras em `Theme.swift`, `MixerSection`, `SharedUI`, `ScreenshotEditorView`/`BackdropPopover` (sem papel semântico: adoção exige token novo registrado antes, dívida §9); chip branco do banner de update em `MenuPanelView` (branco fixo nos dois temas sobre card tingido: sem par dinâmico registrado, exige decisão de token/par antes de migração). Achado adjacente reportado: raio literal 7 em `PanelRecentCapturesView` (eixo raio, fora deste recorte). Provas: `swift build` (todos os alvos), re-grep zerado dos padrões migrados. Pendente de prova: inspeção visual nos temas e estados afetados (HUDs sobre conteúdo real, escuro/claro) pelo operador.
- **2026-10-08, notch em tokens + chip do banner (continuação da varredura):** autorizada pelo operador a fatia do notch e o restante padronizável. (1) Conteúdo branco da ilha migrou para `fg.primary` (par fg.primary/preto 19.09 PASS, §8): defaults `tint` e fallbacks `?? .white` dos componentes (capsule, meter, equalizer, slider, timeline, strip, agent chip/ring, lock screen, mirror, files, calendar month/strips, system, notice), tint de ambiente `.tint(.white)` → `.tint(fg.primary)`, opacidades de conteúdo (`.white.opacity`) → `fg.primary.opacity`. `Color.mint` de atividade em curso (cronômetro/agenda "ongoing") → `awakeActive` (#D89B4A: a cor de sessão já medida sobre preto, 8.71 PASS; o valor de sessão não ganha cor nova). `Color.secondary`/`Color.purple`/`systemPurple` (mixer, watch) → `fg.secondary` (8.13 sobre preto); o texto da leitura do Watch e o olho macio consumem `fg.primary`/`fg.secondary` (espelho NSColor novo: `fgPrimaryNSColor`/`fgSecondaryNSColor`, mesmos valores dos papéis, para desenho em canvas/AppKit). Intactos por classe: preto físico da ilha e recortes, scrims/backdrops/veis pretos, fade de borda, sombras e glow sobre artwork, anel preto de knob sobre capa, tinta preta do dia selecionado (par invertido sobre círculo claro) e mockups dos Ajustes (retratado, §9). (2) Chip do banner de atualização (`MenuPanelView`): `.white` → `surface.raised` com conteúdo no tint do card; pares já registrados (fg.secondary/raised 7.32 escuro, 7.10 claro; chip/card não-texto ~7.8 e ~6.9) — nenhuma cor nova, padrão composto por tokens. (3) Raio literal 7 do placeholder de capturas recentes → `Radius.control` (regra de cantos internos 10/6). Provas: `swift build` (todos os alvos), `swift test` (53/53), re-grep zerado de mint/purple/secondary/white de conteúdo no notch. Pendente de prova: inspeção visual da ilha em app rodando (escuro sempre; contraste sobre vidro não é certificável na §8) e do banner no tema claro/escuro pelo operador. Defeito pré-existente reportado, não corrigido: título do banner (`fg.primary`) sobre card `status.warning` no tema escuro fica abaixo de AA; exige decisão de par próprio do banner.
- **2026-10-08, onda 2 da padronização (orquestração):** extensão do `HexaIconButton`/`HexaIconButtonStyle` com `iconTint: Color?` (contrato em §7: estado de consumo via token no ÍCONE, container padrão); botão de limpar logo do marca d'água (Media) no primitive; `FullDiskAccessNote` no desenho canônico; páginas `Form(.grouped)` dos Ajustes (App Updates, Advanced, Shortcuts, ScreenCapture) e de `ScreenshotSettings` convertidas ao cartão único com âncoras de seção preservadas (`settingsSectionAnchor` + `Radius.panel`); `MonitorSettings.groupHeading` no token de seção (sem ícone: SectionLabel não tem slot); botões de ícone com estado (energia, ejeção, ocultar) no primitive via `iconTint`; `KillProcessView` e `UninstallerView` sem `Form` nativo (últimos fora do notch). **Zero `Form`/`.formStyle` nativo fora da fatia notch; zero título de página fora do token; zero accent de sistema.** Isenções/pendências registradas: tiles de métrica do `QuickControlPanel` (traço permanente + respiro antes do rodapé fixo: anatomia de tile de condição, conversão pendente de decisão do operador); `PanelSection.editButton` "OK" (anatomia icon+texto fora do icon-only, decisão de spec pendente); `HexaDomainNav` (navegação embutida do notch, forma anterior, §9); toggles fora de Form usam `TrailingSwitchToggleStyle` para preservar switch com rótulo. Provas: `swift build` (todos os alvos), `swift test` (61/61), auditoria fria de cobertura (zero violação nova). Pendente de prova: inspeção visual (dois temas, render real) pelo operador.
- A cada superfície concluída: registrar aqui a superfície, tokens e primitives adotados, provas (gates + inspeção visual) e o próximo boundary. Superfícies fora do recorte permanecem não avaliadas.
- **2026-10-08, padronização de página (sidebar, scaffold, cartão único, botões, tokens de página):** pedido explícito do operador para acabar com a mistura de cards/sidebars/tipografia. Fundação nova registrada em §3 e §7: tokens `featureTitle`/`featureSubtitle` (`PageTypography.title` = 40, absorvendo `FeatureWorkspaceMetrics.titleSize`); cartão único sem contorno (`HexaCard` + `HexaSection`, `hexaCardSurface` com exceção de contraste aumentado) e `panelCard()`/`HexaSectionCardModifier` religados a ele (ramo do notch intocado); sidebar única (`HexaSidebar` + `HexaSidebarRow` + `HexaSidebarSearchField`) adotada nas DUAS janelas (funcionalidades e Ajustes) — hover SÓ clareia texto, sem fill e sem crescimento (também na `HexaDomainRail` do painel); scaffold único (`HexaScreenScaffold`) sem respiro inferior, adotado na janela de funcionalidades e nas páginas de Ajustes (General, GeneralTool, Monitor, Feature Hub, App Updates, ScreenCapture, Shortcuts, Advanced, Sobre/Release Notes); primitivos de botão (variantes primary/secondary do `HexaActionButtonStyle`, `HexaIconButton` regular/small, `HexaAccessButton`, `HexaListItem`) com adoção em Ajustes, painel e módulos; `PermissionRow` e portais de permissão em `HexaAccessButton`. Pendências registradas: páginas `Form(.grouped)` de Ajustes (App Updates, Advanced, Shortcuts, ScreenCapture) mantêm seções nativas internas (exigem outra passada); `SettingsCard` sobrevive só para `NotchSettings.swift` (fatia notch); botões de ícone com estado próprio (energia/ejeção/edição) não convertidos (perderiam informação de estado); grid de tiles do hub não existia (hub é lista); botão de limpar logo de marca d'água do Media aguarda chave de localização. Provas: `swift build` (todos os alvos), `swift test` (61/61), `git diff HEAD --check` (única reprovação: whitespace pré-existente em `Services/Cleaner/CleanerSupport.swift:271`, trabalho não commitado anterior ao recorte). Pendente de prova: inspeção visual nos dois temas (render real em app rodando) pelo operador; regras de grid/ícone ficam registradas em §7 para a futura fatia do notch.
- **2026-10-09, dívidas aceitas e paleta de conteúdo (auditoria Setor 2):** (1) Dívida aceita de mockup: `GeneralSettings.swift` (mockup de janela de navegador com gradientes e traffic lights literais, raio 5 e paddings 6/14 fora da escala). É retratado, mesma família do mockup da menu bar em `MonitorSettings`: a cor é o conteúdo retratado, não chrome de UI. (2) Dívida aceita de chrome de canvas: handle de seleção/crop em `ScreenshotEditorView.swift` (branco fixo sobre conteúdo exportável), mesma família de tints/knob/sombras já registradas para esse arquivo. (3) Paleta de conteúdo: os tints do `KeepAwakeIconPicker` (laranja, verde, azul, roxo, rosa, literais de sistema) são escolha do usuário para o ícone de Manter acordado, registrados como paleta própria de conteúdo, NÃO colapsados nos `status.*` — mesma natureza dos `settingsTint` do notch, das cores de barra de uso e de `PanelMetricColor`. (4) Nota factual: o picker de ícone/tint de Manter acordado EXISTE na UI; as frases desta spec que dizem "não existe personalização do ícone ou cor" referem-se ao ícone da menu bar (DEC-018), que permanece fixo. O escopo da isenção é o ícone da menu bar, não o picker.
- **2026-10-09, exceção de ScrollView nativo (auditoria Setor 2):** exceção registrada para três páginas que permanecem em `ScrollView` nativo, cada uma com motivo funcional: o preview de métricas em `MonitorSettings` (usa `pinnedViews` para fixar o cabeçalho durante a rolagem, sem equivalente no `OverlayScrollView`); a busca do hub em `FeatureHubSettings` (usa `ScrollViewReader` para revelar a seção encontrada, com `LazyVStack` como conteúdo direto do `ScrollView`, já anotado como decisão de performance em comentário); e o Cleaner (o `ScrollView` carrega a safe area do split view). O `OverlayScrollView` segue canônico para as demais páginas, e exceção nova exige registro aqui.
- **2026-10-09, token fg.inverse (correção ISSUE-052, auditoria Setor 2):** o dia selecionado do calendário do notch (tinta sobre círculo claro, par invertido) migra do literal `.black` para o token semântico `fg.inverse` (escuro: ink #201D17, claro: bone #F6F4EE), consumindo a base `ink` de §2.1 pela camada semântica. Mesmos valores do par auditado fg.primary/base claro (15.28 PASS, §6); nenhuma mudança visual. Dias fora do mês consomem `fg.disabled` (isenção já registrada). A isenção anterior que tratava a tinta preta do dia selecionado como retratado fica substituída por este token.
- **2026-10-09, conciliação da dataviz:** `PanelMetricColor` está totalmente mapeado para tokens neutros em `Sources/Hexa/UI/Theme.swift` (canais green/cyan/mint/yellow/red/orange/pink → `accent.solid`, `fg.secondary`, `fg.primary`, `accent.text`), consumando a direção de 2026-10-07 ("a dataviz usa canais neutros"). As frases datadas de 2026-10-06 e 2026-10-08 que descrevem paleta própria não colapsada permanecem como registro histórico e não descrevem mais o estado atual. A isenção de paleta de conteúdo (retratado) para mockups, tints do notch e cores de barra de uso vale por si só, sem analogia a `PanelMetricColor`. Nenhum código mudou nesta conciliação.
- **2026-10-09, respiro de fim de conteúdo (scaffold e sidebar):** respiro inferior NÃO é padding fixo do `HexaScreenScaffold` (padding no body mostra a margem o tempo todo, e não só no fim da rolagem): é box de altura fixa (`Spacing.m`, 12) no FIM do corpo rolável, propriedade de quem compõe o conteúdo. Na janela de funcionalidades, o helper `scroll` adiciona o tail a todas as telas roláveis (caso do mixer de volume). Na sidebar única, o bloco fixo da base fica restrito ao que está da borda para baixo: a lista rola ATÉ o divisor (sem respiro fixo fora do rolamento; o respiro de fim de lista é box de altura fixa do consumidor dentro do rolamento), e a `HexaSidebar` ganhou slot fixo opcional (`footerExtra`) entre a borda e o botão: em Ajustes, as linhas Novidades e Sobre saíram da lista rolável para serem fixas no rodapé. Telas que rolam sozinhas (Cleaner, Uninstaller e afins) entram direto no slot e ficam fora deste recorte. A entrada de 2026-10-08 que registra o scaffold sem respiro inferior permanece como registro histórico. Provas: `swift build` (todos os alvos), `swift test`, `git diff HEAD --check`. Pendente de prova: inspeção visual (dois temas, telas com e sem rolagem) pelo operador.
- **2026-10-11, reconciliação pós-unificação:** a composição operacional atual usa `FeatureWorkspaceView`, `HexaSidebarRow` e `HexaSidebarSearchField` na janela única; não há host `HexaSidebar` nem sidebar separada de Ajustes. Feature Hub usa SectionLabel externo ao cartão. A seleção da aba do Monitor é preservada ao abrir outros módulos. O toggle da superfície de Brilho controla apenas os monitores; a linha da luz do teclado permanece independente. No notch, o scroll vertical de página em `NotchView` usa `notchScrollEdgeFade`; com letra/fila abertas, o viewport interno usa o budget real e o scroll externo é desligado. Sem extra, a altura mínima do player e o scroll externo permanecem. Nenhum token ou cor foi criado nesta adoção. Consulte §8 para gates e pendências visuais.
- _Superação de vigência: as descrições de 2026-10-08/09 sobre sidebar duplicada em duas janelas, `HexaSidebar.footerExtra` e cauda de 12 pt pertencente ao consumidor são históricas. O contrato atual da sidebar e do scaffold está em §7; o scaffold usa `Spacing.pageGap` de 24 pt no fim do conteúdo rolável._
- **2026-10-13, padrão de botões por papel (superfície Atalhos):** `ShortcutRecorderButton` deixa o bezel do sistema e adota o casco da ação neutra (§7): altura do `controlSize` (36 regular, 28 mini/small), raio 6, fonte `label`, e fundo, hover, pressionado, desabilitado e anel de foco iguais aos do `HexaActionButtonStyle`. Superfícies alcançadas, por ser um único componente: linhas de atalho de Ajustes (Atalhos, Captura de tela, OCR, Manter acordado e Brilho) e a linha de ferramenta de captura em `ScreenshotToolOrderControls`, que pede `controlSize` pequeno para manter a linha compacta (28). Tokens: nenhum token novo; espelhos NSColor `surfaceInsetNSColor` e `focusRingNSColor` em `HexaTheme`, com os mesmos valores dos papéis. `HexaActionButtonStyle` não mudou. Contraste: `fg.primary` sobre `surface.inset` e sobre `selection.bg` já está medido em §6, nos dois temas; o hover fica entre esses dois fundos, e o desabilitado usa o valor de `fg.disabled`. Provas: `swift build` de todos os alvos, `swift test` (132 testes, zero falhas) e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual nos dois temas e nos estados normal, hover, pressionado, foco, gravando, desabilitado e com texto longo, pelo operador (ISSUE-086, aguardando VERIFIED).
- **2026-10-13, densidade compacta e gaps verticais da sidebar:** adoção de `HexaTheme.Density.rowCompact` (28 pt) em `HexaSidebarRow` (era `rowStandard` de 36 pt), redução do espaçamento entre itens da lista para 2 pt, redução dos respiros dos cabeçalhos de seção para `Spacing.s` (8 pt) no topo e `Spacing.xs` (4 pt) na base, e respiro pós-busca para `Spacing.s` (8 pt). Economia total vertical de ~230 pt na janela operacional, acomodando os 17 itens na altura padrão sem esticar a sidebar. Provas: `swift build`, `swift test`, `git diff HEAD --check`.
- **2026-10-13, padding do painel rápido (QuickControlPanel):** a pedido do operador, as margens do cabeçalho (marca e nome do Mac) e do bloco de métricas e atalhos passam de `Spacing.xl` (20 pt) para `Spacing.l` (16 pt), na horizontal e no topo do cabeçalho e na horizontal e na base do bloco, igualando o padding do rodapé Abrir hexa (`Spacing.l`). Exceção nominal ao inset de painel de 20 pt (§4), restrita a este painel. A isenção de 2026-10-08 sobre a anatomia dos tiles (traço permanente) segue pendente; este ajuste trata só do padding. Provas: `swift build` (todos os alvos), `swift test` (162 testes, zero falhas) e `git diff HEAD --check` no arquivo alterado. Pendente de prova: inspeção visual nos dois temas pelo operador.
- **2026-10-14, módulos na sidebar da janela operacional:** contrato registrado em §7 (subseção da sidebar) antes da implementação. Recursos relacionados passam a ser agrupados em módulos com controle segmentado no topo da coluna de conteúdo: "Processos e portas", "Captura de tela" e "Energia e telas". O cabeçalho de grupo aparece só com duas ou mais linhas visíveis. O espaço entre os itens da lista de funcionalidades sobe para `Spacing.xs` (4 pt); a lista de sistema mantém 2 pt. A altura da linha segue em 30 pt (`Density.rowSidebar`). Substitui, para a sidebar, a frase de 2026-10-07 "sidebar (Lista plana de páginas)" desta seção, que permanece como registro histórico. _Alterado 2026-10-14 — era: gap de 2 pt entre itens; cabeçalho de grupo exibido em todos os grupos, com 8 pt acima e 4 pt abaixo do rótulo. Motivo: pedido do operador por mais espaço entre os itens e menos linhas na lista; os módulos reduzem a contagem de linhas. O gap da lista de funcionalidades passa para 4 pt; a lista de sistema segue em 2 pt (ponto aberto). Os 8 pt e 4 pt do cabeçalho seguem para os grupos que mantêm o cabeçalho; grupos com uma linha deixam de exibi-lo._ Status: pendente de aprovação visual do operador. Provas: código implementado em `FeatureWorkspaceView.swift` e `FeatureSidebarModule.swift`; gates e revisão visual pendentes. Esta entrada não declara gate executado nem aparência aprovada.
- **2026-10-16, módulo Manutenção na sidebar da janela operacional:** centralização dos recursos de manutenção ("Limpeza", "Desinstalador" e "Atualizações") sob a nova linha de módulo "Manutenção" no grupo Ferramentas, com controle segmentado no scaffold e alternância de ajustes no trailing do cabeçalho quando aplicável. Provas: código implementado em `FeatureSidebarModule.swift`, `FeatureWorkspaceView.swift` e `FeatureHubStrings.swift`.
- **2026-10-25, lista reta da sidebar da janela operacional:** o cabeçalho de grupo sai da lista de funcionalidades (ISSUE-770). A lista passa a correr reta, na ordem dos grupos do catálogo (`FeatureGroup`), sem subdivisão rotulada; a seção `Preferências` no rodapé mantém seu `SectionLabel` e seu `HairlineDivider`. Motivo (pedido do operador): o rótulo ocupava a mesma coluna das linhas clicáveis (20 pt em ambos os casos: 8 do container + 12 do rótulo ou da linha) e competia com elas, sendo clicado sem efeito; a fronteira dos rótulos também não era fiel, porque a regra de exibir só em grupos com duas ou mais linhas deixava Dynamic Island (grupo de uma linha) dentro do bloco "Utilitários". Nenhum token novo, nenhuma primitive nova, nenhuma string alterada: `hub.groupSound`, `hub.groupEnergyDisplay`, `hub.groupTools` e `hub.groupMonitor` continuam em uso pelo Hub de Recursos e pela página de Atalhos; `hexaSectionLabel` continua em uso pelo rótulo "Preferências". A função `groupTitle` saiu junto do cabeçalho. Gap entre linhas, altura de linha, seleção, hover, busca e ordem dos grupos permanecem como registrados na §7. Provas: `swift build` verde em todos os alvos; `swift test` do recorte (sidebar, busca da sidebar, abas do workspace e regressão de settings) com 56 testes e 0 falhas; `git diff HEAD --check` limpo. A rodada completa de `swift test` teve 3 falhas de timeout de 60 s em varredura de disco (`SpaceInventoryTests`, `CodingConversationCleanupTests`), pré-existentes e sem relação com a sidebar: reproduzidas com o arquivo de código em `HEAD` (sem a mudança) e sem referência à sidebar. Pendente de prova: inspeção visual nos dois temas, com e sem busca, e verificação de que a lista corre reta e o "Dynamic Island" sai do bloco "Utilitários" (ISSUE-770).
- **2026-10-25, piso de altura da janela operacional em 690 pt:** a altura mínima da janela cai de 740 para 690 pt, junto do piso inicial (que já era 740) e do valor de fábrica. Pedido do operador, na sequência da remoção do cabeçalho de grupo da lista de funcionalidades da sidebar: com a lista mais curta e as posições ajustadas, a janela pode ser mais baixa. A largura continua travada em 800 pt (mínima e máxima) e a altura segue expansível, com alturas maiores salvas preservadas. O piso vale para a janela operacional inteira; Ajustes compartilha a mesma janela, então herda o novo piso. Sem token novo e sem primitive nova: o valor continua em `FeatureWorkspaceMetrics.height`, de onde `minHeight` herda. Contrato atualizado nas duas entradas de superfície que registram a geometria da janela ("Janela de funcionalidades e painel rápido" e "Unificação de Ajustes, notch e ícones"). Provas: `swift build` verde em todos os alvos; `swift test` verde; `git diff HEAD --check` limpo; probe de apresentação dos ajustes (7 páginas renderizadas no novo piso). Pendente de prova: inspeção visual do operador nos dois temas, confirmando que nenhuma página de Ajustes precisa de 740 pt e que a sidebar continua legível no piso novo.
- Dívida aceita fica listada com justificativa; não sustenta declaração de conformidade global.

### 2026-10-07: correções pré-smoke da auditoria de UI

- Sidebar usa seleção própria em selection.bg + fg.primary sobre surface.base. Geral e Recursos são âncoras iniciais; demais itens são ordenados pelo título exibido.
- Cartão de permissão, header, rail e conteúdo do menu panel têm superfícies opacas sob seus textos. Material permanece chrome, sem sustentar contraste por suposição de wallpaper.
- Preview usa surface.inset, fonte data do MenuBarRenderer e suas medidas compactas. Wordmark reconciliado para tracking -0.02em.
- fg.tertiary escuro reforçado para bone @ 55%, mantendo 4.5:1 em seleção e hover de 5%. fg.disabled permanece @ 50%.
- Disclosures simples e ações consolidados nos primitives. Medidas comuns de controle consomem a escala. Conteúdo gráfico e controles nativos de escolha de valor mantêm exceções funcionais.
- A contagem histórica e a afirmação zero literal proibido de 2026-10-06 não provam conformidade global atual.
- Render real não inspecionado nesta execução. Foco, truncamento, posição e apresentação dos painéis dependem do smoke do operador.

Pares resolvidos após a correção, sRGB com composição de alfa:

| Tema | Par | FG resolvido | BG resolvido | Medido | Resultado |
|---|---|---|---|---|---|
| escuro | fg.primary / raised | #F6F4EE | #211D15 | 15.26 | PASS |
| escuro | fg.secondary / raised | #AEABA4 | #211D15 | 7.31 | PASS |
| escuro | fg.tertiary / raised | #96938C | #211D15 | 5.49 | PASS |
| escuro | focus.ring / raised | #A8A199 | #211D15 | 6.57 | PASS |
| escuro | fg.primary / inset | #F6F4EE | #0D0B08 | 17.87 | PASS |
| escuro | fg.secondary / inset | #A7A5A0 | #0D0B08 | 7.97 | PASS |
| escuro | fg.tertiary / inset | #8D8B87 | #0D0B08 | 5.79 | PASS |
| escuro | focus.ring / inset | #A8A199 | #0D0B08 | 7.70 | PASS |
| escuro | fg.primary / selection.bg s/ raised | #F6F4EE | #312D25 | 12.47 | PASS |
| escuro | fg.secondary / selection.bg s/ raised | #B3B0AA | #312D25 | 6.35 | PASS |
| escuro | fg.tertiary / selection.bg s/ raised | #9D9A93 | #312D25 | 4.91 | PASS |
| escuro | focus.ring / selection.bg s/ raised | #A8A199 | #312D25 | 5.37 | PASS |
| escuro | fg.primary / hover 5% s/ raised | #F6F4EE | #2C2820 | 13.39 | PASS |
| escuro | fg.secondary / hover 5% s/ raised | #B1AFA8 | #2C2820 | 6.69 | PASS |
| escuro | fg.tertiary / hover 5% s/ raised | #9B9891 | #2C2820 | 5.12 | PASS |
| escuro | focus.ring / hover 5% s/ raised | #A8A199 | #2C2820 | 5.76 | PASS |
| claro | fg.primary / raised | #201D17 | #FBFAF6 | 16.09 | PASS |
| claro | fg.secondary / raised | #5A554A | #FBFAF6 | 7.10 | PASS |
| claro | fg.tertiary / raised | #6F6D67 | #FBFAF6 | 4.98 | PASS |
| claro | focus.ring / raised | #6E675C | #FBFAF6 | 5.35 | PASS |
| claro | fg.primary / inset | #201D17 | #ECE8DD | 13.73 | PASS |
| claro | fg.secondary / inset | #5A554A | #ECE8DD | 6.05 | PASS |
| claro | fg.tertiary / inset | #69665E | #ECE8DD | 4.67 | PASS |
| claro | focus.ring / inset | #6E675C | #ECE8DD | 4.56 | PASS |
| claro | fg.primary / selection.bg s/ raised | #201D17 | #EAE8E4 | 13.76 | PASS |
| claro | fg.secondary / selection.bg s/ raised | #5A554A | #EAE8E4 | 6.07 | PASS |
| claro | fg.tertiary / selection.bg s/ raised | #696661 | #EAE8E4 | 4.68 | PASS |
| claro | focus.ring / selection.bg s/ raised | #6E675C | #EAE8E4 | 4.58 | PASS |
| claro | fg.primary / hover 5% s/ raised | #201D17 | #F0EFEB | 14.60 | PASS |
| claro | fg.secondary / hover 5% s/ raised | #5A554A | #F0EFEB | 6.44 | PASS |
| claro | fg.tertiary / hover 5% s/ raised | #6B6963 | #F0EFEB | 4.79 | PASS |
| claro | focus.ring / hover 5% s/ raised | #6E675C | #F0EFEB | 4.86 | PASS |

- Rede por processo: demanda explícita por UUID de superfície. Fechar o menu panel remove somente seus consumidores; a última remoção encerra o sampler e descarta a baseline. Reabrir registra novamente a demanda. Nenhuma lease mantém amostragem depois do fechamento.

Evidências desta execução pré-smoke: swift build de todos os alvos, swift test (53/53), build de distribuição local e codesign --verify --deep --strict aprovados. Varredura de UI fora de UI/Notch sem referências ao accent do sistema ou fontes system. Issues 010 e 011 estão FIXED, com render/interação e observação da parada de leitura ainda não executados no app.

### 2026-10-07: notch preparado para smoke

- NotchIconButton e a barra usam foreground/seleção semânticos; botões recebem anel focus.ring. Tab/Shift+Tab deixam a galeria, Enter/setas da busca não capturam o foco da barra. Rótulos longos seguem em uma linha com rolagem horizontal e revelação do item focado.
- Previews de conteúdo e layout reservam e mostram a mesma barra da ilha. A miniatura física tem escopo escuro; os controles externos seguem surface.inset claro/escuro. Silhueta, safe area, câmera e dimensões do painel embutido continuam derivados do host.
- Títulos e notificações usam Manrope na medição e no desenho. Medidas funcionais delimitadas: banner compacto 11 pt, título de notificação expandida 14 pt e subtítulo 13 pt, compartilhados por NotchNotificationSupport e suas views para prever asas e altura sem corte. Não criam papel tipográfico para UI comum. Header e detalhe usam heading de 15 pt.
- Metadado de horário usa fg.tertiary, sem opacidade adicional. Avisos usam status.warning; progresso de download na tela bloqueada usa fg.secondary. Navegação horizontal embutida respeita Reduce Motion.
- Inspeção estrutural: compacto/expandido, hover, drag, timer, HUD, accessory e notificações; estados normal, foco, seleção, vazio, progresso e erro. Contextos: notch físico/cápsula, painel embutido e editores claro/escuro. A ilha real permanece darkAqua nos dois temas do sistema. Nove rótulos longos têm caminho de rolagem. Render real, VoiceOver e fluidez ainda dependem do smoke do operador.
- Dívida aceita do corpo físico e backdrops (§9) preservada. A tabela abaixo mede superfícies opacas; não declara contraste aprovado sobre vidro ou wallpaper.

| Tema | Par | FG resolvido | BG | Medido | Resultado |
|---|---|---|---|---|---|
| escuro | fg.primary / preto | #F6F4EE | #000000 | 19.09:1 | PASS |
| escuro | fg.secondary / preto | #A2A19D | #000000 | 8.13:1 | PASS |
| escuro | fg.tertiary / preto | #878683 | #000000 | 5.78:1 | PASS |
| escuro | fg.tertiary / inset | #8D8B86 | #0D0B08 | 5.79:1 | PASS |
| escuro | focus.ring / preto | #A8A199 | #000000 | 8.22:1 | PASS |
| escuro | focus.ring / seleção inset | #A8A199 | #201D19 | 6.58:1 | PASS |
| escuro | focus.ring / hover 9% inset | #A8A199 | #22201D | 6.37:1 | PASS |
| escuro | status.warning / preto | #D89B4A | #000000 | 8.71:1 | PASS |
| escuro | status.warning @80% / preto | #AD7C3B | #000000 | 5.72:1 | PASS |
| claro | fg.primary / inset (bolha) | #201D17 | #ECE8DD | 13.73:1 | PASS |
| claro | focus.ring / inset (bolha) | #6E675C | #ECE8DD | 4.56:1 | PASS |

Evidência do recorte notch: swift build de todos os alvos, swift test (53/53), ./build.sh, codesign --verify --deep --strict build/hexa.app e git diff HEAD --check aprovados. Não foi executado smoke de grants, teclado, VoiceOver ou render neste recorte. ISSUE-012 está FIXED e aguarda verificação real.

## FanControl: reparos pré-smoke de 2026-10-07

Superfícies FanControlSection/FanControlCurveEditor: estado de recuperação não confirmada em `status.danger`, parada de segurança e alterações não aplicadas em `status.warning`; valores/status pontuais em `data`, textos de apoio em `label`. Curva e pontos usam `accent.solid` sobre `surface.inset` (papel informativo da curva, não status), e a grade usa hairline decorativa. O fundo é opaco para resolver o par real de contraste. Contraste não-texto WCAG medido: `accent.solid`/`surface.inset` escuro #A8A199/#0D0B08 = 7,70:1; claro #6E675C/#ECE8DD = 4,56:1. Ambos PASS (3:1). Textos warning/danger sobre o cartão raised usam os pares já aprovados na matriz §6. Botões de edição usam HexaActionButtonStyle, com foco semântico; o gráfico anuncia os pontos e os steppers anunciam fonte, propriedade e índice. Animação da ventoinha respeita Reduce Motion. Mensagens novas e correção de mensagem de falha cobrem os 15 idiomas.

A exceção de sessão ativa/recuperação foi autorizada pelo operador e registrada sob DEC-002. Retorno automático depende de confirmação do hardware: o estado de recuperação permanece visível até confirmação. Não há declaração de produção ou equivalência visual por inspeção de código. Revisão visual clara/escura, teclado, VoiceOver, overflow, contexto de notch quando habilitado e falhas físicas ficam para o smoke do operador.

Validação estrutural final do FanControl: build de todos os alvos e bundle assinado passaram; 53 testes existentes passaram (11 de política); selftest do helper assinado passou; requisitos de assinatura conferidos e Team ID diferente rejeitado; localização em 15 idiomas/47 campos conferida; diff sem whitespace inválido. Esses gates não exercitam a refrigeração física, o transporte XPC real ou a apresentação visual. Evidência detalhada e limitações em `.app-work/issues/ISSUE-013.md`.

## Janela de funcionalidades e painel rápido, 2026-10-07

Direção aprovada pelo operador após o protótipo local: menu bar é painel de consulta e atalhos, com ação imediata de Manter acordado; controles completos vivem em janela própria, independente de Ajustes. Janela inicial 800 × 690 pt, sidebar 220 pt, largura mínima e máxima de 800 pt e altura mínima de 690 pt, expansível; conteúdo tem inset 32 pt e rolagem própria. Cabeçalho display 40 pt, corpo/labels/data seguem os papéis existentes. Ajustes concentra preferências, disponibilidade, atalhos e permissões. _Alterado 2026-10-10 — era: 740 × 740 pt, com largura mínima e máxima de 740 pt. Motivo: ampliar a área de conteúdo à direita; a sidebar mantém 220 pt._ _Alterado 2026-10-25 — era: 800 × 740 pt, com altura mínima de 740 pt. Motivo: pedido do operador, depois da remoção do cabeçalho de grupo da lista de funcionalidades da sidebar e do ajuste de posições que a acompanharam; a lista ficou mais curta e a janela pode ter o piso menor. O piso vale para a janela operacional inteira (Ajustes compartilha a mesma janela). Alturas maiores salvas continuam preservadas._ _Alterado 2026-10-28 — era: largura mínima e máxima de 800 pt e altura mínima de 690 pt, sem limite pela área útil da tela. Motivo: ISSUE-790/slice M18 — a janela passa a ser limitada pela área útil (visibleFrame) da tela corrente na criação, na reabertura e na troca de tela; 800 × 690 segue como geometria de fábrica quando a tela comporta; ao voltar a uma tela que comporta o piso na mesma sessão, a largura 800 e a altura salva são restauradas; alturas salvas continuam preservadas e nunca são regravadas pelo truncamento._

`surface.inset` escuro passa de #0D0B08 para #1B1812, suavizando a profundidade. Cartões de consulta, campos, barras de segmentos e trilhos consomem esse mesmo token, sem valores locais. A superfície permanece mais escura que raised #211D15. Claro conserva #ECE8DD. Matrizes históricas acima descrevem os valores na data; a medição desta alteração será registrada abaixo.

Tags usam label, contorno hairline, raio control, fg.secondary, conteúdo intrínseco e marcador de forma para status. Estado de Manter acordado tem laranja fixo; não existe personalização do ícone ou cor. Preferências antigas são compatibilidade e não alteram o indicador. A marca na menu bar é sempre o glifo do hexa.

A janela operacional tem demanda própria de monitor, independente da demanda do painel rápido. Fechar/minimizar desmonta o conteúdo operacional e libera seus consumidores; nenhuma janela fechada mantém amostragem de apresentação. Sessões já iniciadas mantêm os ciclos aprovados em DEC-002.

### HexaSwitchStyle

Primitive transversal usado pelo painel rápido e pela sessão de Manter acordado. Anatomia 36 × 22 pt, knob 14 pt, inset 3 pt, contorno focus.ring; desligado em surface.inset e fg.secondary, ligado em fg.primary com knob surface.base. Variante da sessão ativa usa awakeActive: #D89B4A escuro e #8E672C claro. Forma/posição e representação acessível Toggle anunciam o estado. Foco visível por anel 2 pt; animação 0,15 s respeita Reduce Motion; desabilitado preserva semântica nativa.

HexaSegmentControl fornece a superfície surface.inset e o contorno hairline; seus consumidores não precisam recriar a barra. HexaStateTag usa formas distintas (checkmark/exclamationmark/xmark ou dot), texto neutro e contorno, sem fill próprio. O estado ativo de Manter acordado é a única variante colorida dessas tags. Mensagens operacionais de segurança mantêm seus tokens semânticos e textos explícitos. Esses papéis agora usam taupe neutro, conforme a direção aprovada; perigo/aviso/sucesso permanecem distinguidos por texto e forma, sem depender de cor. A dataviz usa canais neutros e conserva rótulos/legendas. Cor funcional de conteúdo (imagem, anotação ou arte de mídia) não é accent de interface.

_Alterado 2026-10-07 — era: status e dataviz em paleta colorida. Motivo: direção minimalista aprovada, com laranja reservado ao estado ativo de Manter acordado e estado distinguido por texto/forma._

### Contraste vigente da migração operacional

Medição sRGB/WCAG 2.1 dos tokens resolvidos sobre superfícies opacas, texto 4,5:1 e foco/controle 3:1. Sobrepõe medições históricas para os papéis alterados; hairlines decorativas e controles desabilitados mantêm isenções nominadas. Não constitui prova de render nativo.

| Tema | Par | FG | BG | Contraste | Resultado |
|---|---|---|---|---|---|
| escuro | primary/base | #F6F4EE | #17140F | 16.70:1 | PASS |
| escuro | secondary/base | #AAA8A2 | #17140F | 7.72:1 | PASS |
| escuro | tertiary/base | #928F8A | #17140F | 5.70:1 | PASS |
| escuro | focus/base | #A8A199 | #17140F | 7.19:1 | PASS |
| escuro | status/base | #B8B2A9 | #17140F | 8.73:1 | PASS |
| escuro | awake/base | #D89B4A | #17140F | 7.62:1 | PASS |
| escuro | primary/seleção sobre base | #F6F4EE | #282520 | 13.88:1 | PASS |
| escuro | primary/raised | #F6F4EE | #211D15 | 15.26:1 | PASS |
| escuro | secondary/raised | #AEABA4 | #211D15 | 7.32:1 | PASS |
| escuro | tertiary/raised | #96938C | #211D15 | 5.47:1 | PASS |
| escuro | focus/raised | #A8A199 | #211D15 | 6.57:1 | PASS |
| escuro | status/raised | #B8B2A9 | #211D15 | 7.98:1 | PASS |
| escuro | awake/raised | #D89B4A | #211D15 | 6.96:1 | PASS |
| escuro | primary/seleção sobre raised | #F6F4EE | #312D25 | 12.46:1 | PASS |
| escuro | primary/inset | #F6F4EE | #1B1812 | 16.10:1 | PASS |
| escuro | secondary/inset | #ACA9A3 | #1B1812 | 7.55:1 | PASS |
| escuro | tertiary/inset | #93918B | #1B1812 | 5.62:1 | PASS |
| escuro | focus/inset | #A8A199 | #1B1812 | 6.93:1 | PASS |
| escuro | status/inset | #B8B2A9 | #1B1812 | 8.41:1 | PASS |
| escuro | awake/inset | #D89B4A | #1B1812 | 7.34:1 | PASS |
| escuro | primary/seleção sobre inset | #F6F4EE | #2C2822 | 13.32:1 | PASS |
| escuro | knob/awake ativo | #17140F | #D89B4A | 7.62:1 | PASS |
| claro | primary/base | #201D17 | #F6F4EE | 15.28:1 | PASS |
| claro | secondary/base | #5A554A | #F6F4EE | 6.74:1 | PASS |
| claro | tertiary/base | #6D6A64 | #F6F4EE | 4.90:1 | PASS |
| claro | focus/base | #6E675C | #F6F4EE | 5.08:1 | PASS |
| claro | status/base | #5C564B | #F6F4EE | 6.61:1 | PASS |
| claro | awake/base | #8E672C | #F6F4EE | 4.63:1 | PASS |
| claro | primary/seleção sobre base | #201D17 | #E6E3DC | 13.11:1 | PASS |
| claro | primary/raised | #201D17 | #FBFAF6 | 16.09:1 | PASS |
| claro | secondary/raised | #5A554A | #FBFAF6 | 7.10:1 | PASS |
| claro | tertiary/raised | #6F6D67 | #FBFAF6 | 4.95:1 | PASS |
| claro | focus/raised | #6E675C | #FBFAF6 | 5.35:1 | PASS |
| claro | status/raised | #5C564B | #FBFAF6 | 6.96:1 | PASS |
| claro | awake/raised | #8E672C | #FBFAF6 | 4.87:1 | PASS |
| claro | primary/seleção sobre raised | #201D17 | #EAE8E4 | 13.73:1 | PASS |
| claro | primary/inset | #201D17 | #ECE8DD | 13.73:1 | PASS |
| claro | secondary/inset | #5A554A | #ECE8DD | 6.05:1 | PASS |
| claro | tertiary/inset | #69665E | #ECE8DD | 4.68:1 | PASS |
| claro | focus/inset | #6E675C | #ECE8DD | 4.56:1 | PASS |
| claro | status/inset | #5C564B | #ECE8DD | 5.94:1 | PASS |
| claro | awake/inset | #8E672C | #ECE8DD | 4.16:1 | PASS |
| claro | primary/seleção sobre inset | #201D17 | #DDD9CE | 11.92:1 | PASS |
| claro | knob/awake ativo | #F6F4EE | #8E672C | 4.63:1 | PASS |

O glifo de Manter acordado e o switch compartilham awakeActive via a mesma fonte NSColor dinâmica. Atualização disponível mantém o ícone neutro e não substitui o laranja de uma sessão ativa.

### Cobertura e provas desta migração

Implementados: painel rápido da menu bar; janela operacional com sidebar, busca, cabeçalho e seleção de métricas; Mixer em cartões próprios; controles existentes de Manter acordado, brilho, rede, discos, energia e FanControl; ferramentas existentes na janela própria; seleção local das extensões da ilha; links operacionais em Ajustes. Preferências de visibilidade e ordem de ferramentas preservadas. Nenhuma operação destrutiva foi executada na validação.

Gates estruturais: build de todos os alvos, 53 testes existentes, bundle de distribuição local e matriz de 44 pares de contraste. A verificação final da assinatura e o diff são registrados no fechamento. Sem testes novos. Código paralelo preservado.

Render nativo, temas/estados no app, foco/VoiceOver, idiomas longos e o ciclo real de coexistência/fechamento das janelas permanecem NÃO EXECUTADOS: a ferramenta de inspeção nativa falhou ao iniciar. A aprovação visual do protótipo não demonstra equivalência do render SwiftUI; a migração não é declarada visualmente verificada. Superfícies da ilha fora dos tokens compartilhados não foram redesenhadas nesta slice.

Fechamento estrutural: build de todos os alvos e bundle atualizado passaram; 53/53 testes existentes, codesign --verify --deep --strict e git diff --check aprovados. Nenhum smoke ou render nativo declarado.

## Ícone e arte do instalador, 2026-10-07

O ícone mantém o Conceito A e agora fornece quadrado opaco #17140F até os quatro cantos. A máscara de apresentação externa é responsabilidade do macOS; não pré-recortar o SVG nem rasterizar cantos sobre branco. ICNS inclui 16/32/64/128/256/512/1024 px, preservando bone/latão da marca. A fonte vetorial é AppIcon.svg; RenderBrand.swift gera os PNGs e iconutil monta o ICNS.

O Finder do DMG usa janela de 720 × 500 pt e fundo raster em 2× (1440 × 1000 px, 144 dpi): carvão, logo central e wordmark Instrument Serif, com a itálico em latão. App e atalho Applications ficam em (175,380)/(545,380), ícones 96 pt; instrução bilíngue usa Manrope com foreground bone a 66%/55%. Esses pares já estão cobertos pela matriz de foreground sobre base, junto do brand.text escuro; a arte não introduz accent de interface.

Prévia visual inspecionada no PNG; cantos opacos do ícone medidos em RGBA (23,20,15,255). A apresentação real do Finder/Dock depende do cache e máscara do sistema e não é declarada comprovada somente pela arte.

Arte de instalador: área 720 × 500 pt, janela do Finder 720 × 528 pt para reservar título. A prévia local contém os aliases e a arte em metadados verificados; ICNS extraído do disco mantém os cantos escuros. Render nativo do Finder não foi inspecionado, pois a conexão da ferramenta falhou.


### Refinamento do painel rápido, 2026-10-07

Painel de consulta com largura 420 pt e altura intrínseca, sem ScrollView: cabeçalho, até quatro métricas, Manter acordado e rodapé. Removida a lista de atalhos operacionais; as funcionalidades continuam na janela própria. O estado ativo não acrescenta linhas de botões. Rodapé usa HexaActionButtonStyle: Abrir hexa ocupa a largura disponível dentro do label; Ajustes é engrenagem com nome acessível e tooltip. Mesmos tokens e pares de contraste já medidos para fg.primary, fg.secondary, selection.bg, surface.raised, surface.inset e focus.ring; nenhum novo par.

Hospedagem usa a área de conteúdo padrão do NSPopover, sem full-size content, e NSHostingController.safeAreaRegions vazio. Isso evita somar a safe area à dimensão intrínseca da raiz e deslocar o conteúdo para baixo/esquerda. Mantida a moldura nativa, sem borda local duplicada. Critério: ausência de faixa assimétrica, ausência de scroll, acesso por teclado às métricas/Toggle/rodapé e demanda liberada ao fechar. A prova estrutural não substitui inspeção nativa do popover.

Validação deste refinamento: todos os alvos compilados, 53 testes existentes passaram, pacote local gerado e assinatura estrita verificada. Revisados estruturalmente foco dos botões/Toggle, conteúdo longo, zero/quatro métricas e demanda por visibilidade. Pares de cor herdados nos dois temas; inspeção nativa dos temas, estados ativo/inativo, foco e moldura NÃO EXECUTADA por falha da ferramenta de UI. ISSUE-016 em FIXED, aguardando prova visual.


## Unificação de Ajustes, notch e ícones, 2026-10-07

Ajustes usa a janela operacional inicialmente em 800 × 690 pt, largura mínima e máxima de 800 pt, altura mínima de 690 pt e máxima expansível, sidebar 220 pt. Alturas maiores salvas são preservadas; larguras antigas são normalizadas para 800 pt. _Alterado 2026-10-10 — era: 740 × 740 pt, com largura mínima e máxima de 740 pt e larguras antigas normalizadas para 740 pt. Motivo: ampliar a área de conteúdo à direita; a sidebar mantém 220 pt._ _Alterado 2026-10-25 — era: 800 × 740 pt, com altura mínima de 740 pt. Motivo: mesmo pedido do operador que baixou o piso da janela operacional; Ajustes compartilha essa janela._ _Alterado 2026-10-28 — era: largura mínima e máxima de 800 pt e altura mínima de 690 pt, sem limite pela área útil da tela. Motivo: ISSUE-790/slice M18 — o mesmo encaixe pela área útil (visibleFrame) da tela corrente, na criação, na reabertura e na troca de tela; Ajustes compartilha essa janela, então herda o limite, a geometria de fábrica de 800 × 690 quando a tela comporta, a restauração de 800/altura salva ao voltar a uma tela que comporta o piso e a não regravação da altura salva pelo truncamento._ As páginas e a busca existentes são preservadas, sem outra janela ou toolbar nativa. Sidebar, cabeçalho e conteúdo usam surface.raised, surface.base, surface.inset, fg.primary/secondary, selection.bg e focus.ring. A troca entre funcionalidades e Ajustes desmonta o conteúdo anterior e libera sua demanda de apresentação.

Ícones de interface: Lucide 1.52.0, contornos monocromáticos, distribuídos no bundle com sua licença. Primitive de ícones compartilhado por SwiftUI e AppKit; nomes legados são mapeados explicitamente para semântica Lucide para preservar estados dinâmicos e acessibilidade. Tamanho padrão 16 pt; tamanho informado pelo consumidor preservado nos papéis display e controles. Sem fallback SF Symbols. Logos de aplicativos, artwork e a marca própria são conteúdo, não ícones de interface.

Notch conserva o preto da superfície exterior e tema escuro. Cartões internos usam surface.raised/inset; seleção selection.bg, títulos e labels nos papéis existentes, foco focus.ring, raio control/panel e separadores hairline. Manter acordado ativo usa awakeActive sobre surface.base; demais estados são neutros com forma/texto. Cores de conteúdo (artwork, calendário configurado e mídia) permanecem dados, não navegação. Exceção: geometria física da ilha, do recorte da câmera e dos controles compactos conserva medidas de NotchLayout; não importar a geometria da janela para o notch.

### Pares resolvidos no contexto preto do notch

Método WCAG 2.1, sRGB linearizado e alpha composto sobre a superfície real. Valores: preto #000000, raised #211D15, inset #1B1812, primary #F6F4EE, secondary primary @66%, seleção #A8A199 @12%, foco #A8A199, sessão #D89B4A, glifo ativo #17140F. Hairline é divisor decorativo, não indicador de estado; seleção/foco usam contorno e texto, não hairline.

| Foreground | Superfície | Tema | Medido | Critério | Resultado |
|---|---|---|---|---|---|
| fg.primary | preto exterior | escuro | 19.09:1 | 4.5:1 | PASS |
| fg.secondary | preto exterior | escuro | 8.13:1 | 4.5:1 | PASS |
| focus.ring | preto exterior | escuro | 8.22:1 | 3:1 | PASS |
| fg.primary | surface.raised | escuro | 15.26:1 | 4.5:1 | PASS |
| fg.secondary | surface.raised | escuro | 7.31:1 | 4.5:1 | PASS |
| focus.ring | surface.raised | escuro | 6.57:1 | 3:1 | PASS |
| fg.primary | surface.inset | escuro | 16.10:1 | 4.5:1 | PASS |
| fg.secondary | surface.inset | escuro | 7.56:1 | 4.5:1 | PASS |
| focus.ring | surface.inset | escuro | 6.93:1 | 3:1 | PASS |
| fg.primary | seleção sobre preto | escuro | 16.83:1 | 4.5:1 | PASS |
| fg.secondary | seleção sobre preto | escuro | 7.75:1 | 4.5:1 | PASS |
| focus.ring | seleção sobre preto | escuro | 7.25:1 | 3:1 | PASS |
| fg.primary | seleção sobre raised | escuro | 12.47:1 | 4.5:1 | PASS |
| fg.secondary | seleção sobre raised | escuro | 6.35:1 | 4.5:1 | PASS |
| focus.ring | seleção sobre raised | escuro | 5.37:1 | 3:1 | PASS |
| surface.base (glifo) | awakeActive (sessão) | escuro | 7.62:1 | 4.5:1 | PASS |


### Cobertura e prova da unificação

Implementados: mesma NSWindow para Ajustes e operações; sidebar 220 pt e toolbar 48 pt em Ajustes; no workspace de funcionalidades, recuo superior de 32 pt (logo e título), com 12 pt entre logo e busca; busca e histórico preservados; fechamento, minimização e troca de seção liberam demanda de apresentação. Ícones SwiftUI/AppKit migrados para Lucide local, 346 chaves legadas cobertas e zero carregadores SF Symbols em produção. Contrato dos ícones: imagem template com cor herdada e tamanho explícito, cache de recurso sem amostragem; semântica acessível do Button/Label permanece no consumidor. Ícones decorativos não recebem tab stop. Ícones compostos de SF Symbols são traduzidos para o equivalente semântico Lucide, sem efeitos exclusivos de SF Symbols.

Provas: builds de todos os alvos, 53 testes existentes, pacote local e assinatura estrita; renders isolados de Ajustes nos temas claro/escuro, Controles do notch sobre preto e glifos a 14/32 pt inspecionados. Conteúdo de serviços nos renders é frio; execução real, foco, estados de hardware, transições e todas as páginas não foram inspecionados. Smoke nativo permanece pendente em ISSUE-017 por falha da ferramenta de UI. Não declarar equivalência visual global por esse recorte. A aparência exterior preta e as medidas funcionais da ilha permanecem.


## Grade única de atalhos do notch, 2026-10-08

Configuração: NotchQuickAccessConfiguration centraliza o catálogo e resolve aliases de destinos. Editor e apresentação consomem os mesmos botões. Player/volume/brilho são componentes de conteúdo; ações pertencem à grade inferior. Células: altura 48 pt, largura mínima 112 pt, até quatro colunas e duas linhas; gap 8 pt, padding horizontal 12 pt, texto label em até duas linhas. Última célula Todos dá acesso aos excedentes por menu nativo acessível, sem scroll horizontal. O cálculo geométrico usa o mesmo count/width da view e da prévia em Ajustes. A expansão segue o limite de altura escolhido; páginas de conteúdo podem rolar verticalmente, atalhos permanecem fora desse scroll.

Cores não são redefinidas nesta slice: surface.inset, selection.bg, fg.primary/secondary, focus.ring e awakeActive permanecem nos tokens canônicos, sob trabalho paralelo de paleta. Pares já medidos são reutilizados; validade visual acompanha os valores atuais do tema e o smoke. Migração conserva o primeiro ID/nome por destino equivalente e incorpora os atalhos anteriores do bloco Controles antes da primeira edição salvar a versão unificada.


Cobertura desta unificação: grade executável e editor compartilham NotchQuickButtonLabel; catálogo único com aliases resolvidos e ações únicas. Estado normal/selecionado/sessão usa os tokens já existentes, sem nova cor. Foco vem de NotchButtonStyle; botões têm título completo em help/acessibilidade, mesmo quando o texto de duas linhas é truncado. Todos usa menu nativo, com nomes completos e a ordem configurada. Componentes primários empilham quando não cabem lado a lado; apenas o corpo da página pode rolar sob limites baixos de altura customizada. A edição da grade não replica um seletor de atalhos em Controles.

Provas: 53 testes existentes e build dos alvos aprovados; renders isolados de Controles padrão/compacto e editor inspecionados. Tema claro N/A, notch tem identidade escura. Dados reais, foco/VoiceOver, menu Todos, transições físicas e todos os idiomas no app permanecem pendentes de smoke. A matriz de cor permanece sob trabalho paralelo da paleta; esta slice reutiliza os pares canônicos sem redefinir seus valores. Não declarar conformidade visual global a partir desses renders.

## Container de rolagem padrão, 2026-10-08
OverlayScrollView é o container de rolagem canônico das superfícies UI/.
_Alterado 2026-10-10 — era: NSViewRepresentable sobre NSScrollView do AppKit com subview OverlayScrollIndicator manual. Motivo: o container anterior posicionava incorretamente o indicador em (0,0) desenhando uma barra no canto superior esquerdo e travava a rolagem por conflito de constraints no NSHostingView do clip view. Unificado como casca centralizada sobre ScrollView(.vertical) nativo do SwiftUI com .scrollIndicators(.automatic), garantindo scroller de overlay nativo do macOS à direita e compatibilidade com ScrollViewReader._
_Alterado 2026-10-29 — era: indicador na margem automática da plataforma. Motivo: a margem automática afastava o knob da borda; o indicador fica colado ao lado com `Spacing.xs` (4 pt), na faixa de gutter de overlay da §4._
Feature única em uma tela não cria scroll próprio: emite conteúdo plano e a rolagem acontece no nível da tela, reativa ao tamanho disponível (modelo de Atualizações de apps). Scroll interno é legítimo apenas em região delimitada por desenho (paleta flutuante, micro-lista compacta de painel) ou em elemento com rolagem nativa própria (List). Migração concluída em 2026-10-08: as List nativas de Desinstalador, Kill Process, Port Manager do workspace e resultados do Limpeza viraram OverlayScrollView + LazyVStack com seções preservadas; MediaWorkspaceView unificou os dois ramos (o compacto mede a altura do conteúdo e aplica o teto de 430 pt); as micro-listas compactas de App Updates do painel usam o container canônico com as alturas em rows inteiras preservadas. Provas: build de todos os alvos e testes verdes na integração; inspeção visual dos temas e estados fica pendente de smoke.

## Nota inline de status, 2026-10-09
`HexaStatusNote` unifica os dois idiomas de mensagem de status que a auditoria mapeou com anatomia idêntica: o Text solto em `label` + `statusWarning` (9 ocorrências em Ajustes e captura de tela) e o banner `Label` + ícone semântico + cor de status (App Updates, Desinstalador do workspace e do painel, painel, Media). Fonte `label`, tom `warning` (`statusWarning`) ou `neutral` (`fgSecondary`), quebra vertical livre; sem ícone, ou com ícone opcional no banner. A condição de exibição e os modificadores de recorte (limite de linhas, padding, `panelCard`) permanecem no call site. Fora do recorte por anatomia divergente: banner do Port Manager (`body` + `fgSecondary`), notas do Cleaner em `micro` e centrada, Fan Control e editor de conteúdo do notch em `body`, barra segura de Ajustes (HStack com `fgPrimary`), ícone de 24 pt do Feature Hub, linha de erro do notch com `lineLimit(1)`, anotação de confiança do Desinstalador sem fonte própria e relógios/ícones do notch que usam `statusWarning` como cor de leitura. Provas: `swift build` de todos os alvos, `swift test` e `git diff HEAD --check` verdes; inspeção visual dos dois temas fica pendente do operador.
## Estado ocupado centralizado, 2026-10-09
`HexaBusyState` unifica os cinco idiomas de espera que a auditoria mapeou com anatomia comum: spinner centrado vertical + mensagem em `fgSecondary` (Cleaner e Desinstalador do workspace, com cancelamento durante scan e slot de accessory para o app alvo), spinner + mensagem em painel (seletor de apps do Desinstalador) e spinner solto em painel compacto (Kill Process e Port Manager). Duas variantes canônicas: `workspace` (spinner `.large`, respiro `Spacing.l`, altura mínima 320) e `compact` (spinner `.small`, respiro `Spacing.s`); mensagem, detalhe e ação são opcionais. Normalizações aceitas na adoção: mensagem e detalhe passam a ter fonte explícita (`body`/`label`), spinner compacto do Cleaner em `.regular` e do seletor em janela larga padronizam para `.small`, e o Desinstalador herda a altura mínima de 320 do workspace. Fora do recorte por anatomia divergente: spinners inline dentro de linhas de lista, cabeçalhos e controles (Notch, MenuPanel, Media, FanControl, App Updates), que não são estados de página. Provas: `swift build` de todos os alvos, `swift test` e `git diff HEAD --check` verdes; inspeção visual dos dois temas fica pendente do operador.

## Rodapé de resultados, 2026-10-09
`HexaResultsFooter` unifica o esqueleto do rodapé de resultados com anatomia idêntica: metadados de seleção à esquerda (slot `@ViewBuilder`), `Spacer`, botão secundário plain opcional (reset/cancelar) e botão primário `HexaActionButtonStyle` desabilitável à direita, com padding do rodapé no primitive. Consumidores migrados: `CleanerView.resultsFooter` (padding compacto `Spacing.m`/padrão `Spacing.l`, `controlSize` `.large` no primário) e `UninstallerView.footer` (padding `Spacing.l`, secundário desabilitável durante remoção Homebrew). Fora do recorte por anatomia divergente: `AppUpdatesListView.updateButton` (primário alinhado à esquerda, sem metadado à esquerda, largura infinita em modo compacto), `MediaWorkspaceView.actionRow` (ordem invertida: ações à esquerda, nota à direita) e `PanelUninstallerView.footer` (rodapé em duas linhas, metadados em linha própria). A `HairlineDivider` acima do rodapé permanece no contêiner. Provas: `swift build` de todos os alvos, `swift test` e `git diff HEAD --check` verdes; inspeção visual dos dois temas fica pendente do operador.

## Legenda de seção, 2026-10-09
`HexaCaptionText` unifica o idioma da legenda de apoio multi-linha solta dentro de `HexaSection` (fora de `SettingsRow`, que tem slot de caption próprio): modifier `Text.hexaCaption()` com fonte `label`, cor `fgSecondary` e quebra vertical livre (`fixedSize` horizontal falso, vertical verdadeiro), sem parâmetros. Consumidores migrados: descrição do backup em `AdvancedSettings`, notas de aprovação e aparência em `GeneralSettings`, `panelIntro`/`panelReorderHint` e legenda do mixer em `GeneralToolSettings`, legendas do Monitor (`appearanceStrings.caption` e `reorderHint`) e as legendas de fontes em `AppUpdatesSettings` (que passam a ter quebra vertical livre explícita), além do rodapé do hub em `FeatureHubSettings` (dois Texts, um `hexaCaption` por linha; a composição em VStack segue do domínio). O inset de alinhamento com o texto da row (`settingsRowTextInset`) permanece no call site. Fora do recorte por anatomia divergente: linha de erro de login em `GeneralSettings` (`statusDanger`) e legenda da menu bar em `MonitorSettings` (`body`), que mantêm o idioma anterior. O mesmo idioma aparece difundido fora de Ajustes (Cleaner, MenuPanel, Notch, Media, Homebrew, QuickTools); adoção por superfície fica para as slices do roadmap. Provas: `swift build` de todos os alvos, `swift test` e `git diff HEAD --check` verdes; inspeção visual dos dois temas fica pendente do operador.

## Linha label + valor, 2026-10-09
`HexaKeyValueRow` unifica o par de leitura label + valor à direita em painel: HStack com `Spacing.s`, label em `body` (`fgSecondary`), `Spacer(minLength: Spacing.s)` e valor em `data` (`fgPrimary`), com slot `trailing` opcional para controle inline (botão de ocultar). Consumidores migrados: `DiskSection.smartRow` (todas as linhas SMART do domínio Disco), `NetworkSection.totalsRow` (totais da sessão, com botão de ocultar no slot; normalizações aceitas: espaçamento `xs`→`s`, label `fgTertiary`→`fgSecondary`, valor `fgSecondary`→`fgPrimary`) e duas linhas limpas de `FanControlSection` (intensidade de resfriamento e linha de RPM do fallback, ambas com espaçamento `xs`→`s`). Fora do recorte por anatomia divergente: `PowerSection.row` (bloco de duas linhas com ícone e legenda, valor em `body` mono com largura mínima e `numericText`, label com opacidade própria), `SystemSection.memoryRowContent` (chevron de expansão e indicador de pressão entre label e valor, valor em `fgSecondary`), `MetricDetailView.detailRow` (ramos de valor quebrado, indicador no lugar do valor, escala mínima no título) e `FanControlSection.fanRows` (valor em VStack de duas linhas). Provas: `swift build` de todos os alvos, `swift test` e `git diff HEAD --check` verdes; inspeção visual dos dois temas fica pendente do operador.
## Cabeçalho de painel embutido, 2026-10-09
`HexaPanelHeader` unifica o idioma do cabeçalho de painel embutido com anatomia idêntica nos quatro consumidores mapeados: título com ícone semântico (`Label` + `hexaIcon`, papel `body`) + `Spacer` + 1 a 2 `HexaIconButton` variante `small` com `.help()`. Consumidores migrados: `PanelPortManagerView.header` (gearshape + fechamento), `PanelAppUpdatesView.header` (gearshape + fechamento), `PanelUninstallerView.header` (fechamento com cancelamento de scan) e `PanelRecentCapturesView.header` (limpeza com disabled por lista vazia + fechamento opcional). Os botões permanecem primitivos do consumidor no slot `actions`; o primitive fixa HStack `Spacing.s`, papel `body` e o `Spacer`. Nenhum outro idioma igual foi encontrado no painel; `HexaBreadcrumbHeader` (detail com voltar) não é afetado. Provas: `swift build` de todos os alvos, `swift test` e `git diff HEAD --check` verdes; inspeção visual dos dois temas fica pendente do operador.

## Padronização da base do Scaffold de página, 2026-10-10
O `HexaScreenScaffold` padroniza o layout de telas: bloco fixo de cabeçalho (título, subtítulo, pinned) seguido de respiro fixo de 24 pt (`Spacing.pageGap`) até o início do conteúdo. O padding fixo exterior de 20 pt no rodapé da janela é eliminado (evitando margem morta permanente na base da tela). Em telas roláveis (`scrolls: true`), o respiro de 24 pt (`Spacing.pageGap`) é anexado ao final do conteúdo rolável dentro do `OverlayScrollView`, permitindo overscroll/elevação do final do conteúdo sem prender espaço vazio na janela. Espaçamento padrão entre seções é 16 pt (`Spacing.l`). Provas: `swift build` de todos os alvos, `swift test` e `git diff HEAD --check` verdes.

## Padronização setorial completa (Notch, MenuPanel/Ferramentas e Settings/Shell), 2026-10-12
Varredura e alinhamento estrutural dos 3 setores da aplicação:
1. **Identidade (DEC-011):** `BlackHoleGlyph` renomeado para `HexaStatusGlyph` em `StatusItemController`, `SelfTest`, `GeneralSettings` e `MenuBarMetricsPreview`; ícones residuais `Image(systemName:)` e `.font(.system(...))` em `QuickControlPanel` migrados para `HexaIcons.image` e papéis `HexaFontRole`.
2. **Primitives e componentização (§7):**
   - `SettingsChoiceTile` (`UI/Settings/SettingsCard.swift`): primitive interativo para escolhas visuais em Ajustes (fundo `selection.bg` quando selecionado ou `surface.inset` normal, contorno `accent.solid` 1.5 px ou `border.hairline` 1 px, anel `focus.ring` 2 px via `@FocusState` e trait `.isSelected`).
   - `NotchGlyphBadge` (`UI/Notch/NotchComponents.swift`): badge passivo 56x56 pt com raio `Radius.notch`, fundo `surface.inset` e glifo 26 pt em `fg.secondary`, unificando os 5 estados vazios/setup do Notch.
   - `UsageBar` (`UI/MenuPanel/SystemSection.swift`): unificado com `DiskUsageBar` usando trilha `surface.inset`.
   - `TrailingSwitchToggleStyle` e toggles de Ajustes adotam `HexaSwitchStyle`; botões de ação sem estilo em Ajustes, Homebrew, Atalhos e Cleaner adotam `HexaActionButtonStyle`; `PanelCleanerView` adota `HexaPanelHeader` + `HexaIconButton`; `NotchLockScreenView` reutiliza `HUDBackdrop`; `HexaDisclosure` aplica `withAnimation(toggleAnimation)`; `HexaListItem`, `QuickControlPanel`, `MixerSection`, `KeepAwakeEndTimePicker`, `ScreenshotEditorView`, `NotchActivityPicker` e `NotchSectionsView` recebem anel `focus.ring`.
3. **Tokens e localização:** opacidades avulsas substituídas por `surface.inset`, `border.hairline`, `fg.secondary`, `fg.tertiary` e `fg.disabled`; uso de `awakeActive` fora de Manter acordado migrado para `status.warning`/`accent.solid`; `NotchControlSurface` respeita `cornerRadius`; traduções inline movidas para `GeneralSettingsStrings`, `ScreenshotFeatureStrings`, `ShortcutSettingsStrings`, `PortManagerFeatureStrings`, `NotchStrings` e `Strings`.
Provas: `swift build` (zero erros e zero warnings), `swift test` (132 testes, zero falhas), `./build.sh` com assinatura verificada e `git diff HEAD --check` limpo. Render visual em execução continua sujeito a smoke do operador (§8).

## Cartão leve dos grupos da Limpeza, 2026-10-18
Cada grupo da lista de resultados do Cleaner (seções "Seguro para apagar" e "Opcional, revise antes") fica dentro de um cartão próprio, com o acordeão e as linhas de itens dentro do mesmo cartão. O cartão usa o desenho de superfície do hexa (`hexaSectionCard(padded: false)`: fundo `surface.raised`, raio de painel 10, sem contorno, hairline só com "Aumentar contraste") com respiro próprio, sem o respiro 16 do `HexaCard`: horizontal `Spacing.m` (12), vertical `Spacing.xs` (4), e gap de `Spacing.s` (8) entre cartões. O cabeçalho do grupo continua em `CleanerView.groupRow` (chevron, checkbox independente e rótulo em um único Button). Não há cartão aninhado dentro do acordeão: os itens são linhas planas. O rótulo de seção ("Seguro para apagar", "Opcional, revise antes") continua fora dos cartões, pelo padrão de `SectionLabel`.
Motivo: as categorias ficavam coladas umas nas outras na lista, e o `HexaCard` (respiro 16) pesava demais para uma linha de checkbox. Escolha de composição local de domínio: não criou token nem primitive novo, e não promoveu `HexaCard` para este caso.
Provas: `swift build` verde, `swift test` verde (425 testes), `git diff HEAD --check` limpo para `Sources/Hexa/UI/Cleaner/CleanerView.swift`. Pendente de prova: inspeção visual dos dois temas, com grupos expandido e recolhido, pelo operador (§8).

## Faixa de temperaturas com rótulos, 2026-10-25
A faixa de temperaturas do painel rápido (`UI/Workspace/QuickControlPanel.swift`) volta a exibir o rótulo de cada leitura ao lado do ícone e do valor: `CPU`, `GPU` e `Bateria` no papel `label` em `fg.secondary`, com `lineLimit(1)` e `minimumScaleFactor(0.8)`; o valor segue no papel `data` mono tabular. O `.help()` saiu: com o rótulo visível a tooltip era redundante, e a leitura completa (rótulo + unidade) segue no `accessibilityLabel` de cada item. A temperatura do disco saiu da faixa e passou para o cabeçalho do bloco de discos, ao lado do rótulo "Discos" (`label`/`fg.secondary`, `monospacedDigit`), lendo o SMART do disco interno; ela aparece sob a mesma condição de amostragem de antes, porque o bloco de discos e a leitura SMART compartilham a flag `disk` de `SystemMonitorPanelNeeds` — nenhuma flag nova, nenhuma amostragem em fundo. O ícone de disco repetido ao lado do nome de cada volume (interno/externo) foi removido: sobrou só o nome do disco, e o cabeçalho "Discos" continua com o ícone semântico e o botão de ejeção do volume segue intacto.
Sem token novo e sem primitive novo: `fg.secondary`, `label`, `data`, `surface.inset` e `border.hairline` já medidos na §6 (par `fg.secondary`/`surface.inset` aprovado nos dois temas). Nenhuma string nova: `cpuLabel`, `gpuLabel`, `batteryLabel`, `diskSection` e `diskTemperature` já existem.
Provas: `swift build` verde (todos os alvos), `swift test` verde (452 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` assinado localmente e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual pelo operador nos dois temas (§8) — faixa com 3 e com 4 leituras, rótulos longos, bloco de discos com disco interno e externo, e eixoção do botão de ejeção sem o ícone de disco ao lado do nome.

## Espaçamento das páginas da janela operacional, 2026-10-25
As páginas da janela operacional adotam o gap canônico de seção de 16 pt (`Spacing.l`), com 8 pt entre `SectionLabel` e cartão, 24 pt entre cabeçalho e body e 24 pt no fim do conteúdo rolável. O ajuste cobre Geral, Barra de menus, Recursos, Atalhos, Avançado, Sobre, Monitor, Dispositivos conectados, Manutenção, Processos e portas, Captura de tela e texto/OCR, Energia e tela, Mídia, Dynamic Island, Mixer e Fan Control, incluindo seus segmentos e modos. Scrolls internos fornecem a cauda de 24 pt uma única vez; telas roladas pelo scaffold continuam usando a cauda dele. A Geral foi alinhada de 20 para 16 pt. No catálogo de Recursos, cabeçalhos de grupo usam `SectionLabel` sem ícone decorativo; ícones das funcionalidades e permissões permanecem. Nenhum token ou primitive novo foi criado. Painel compacto da menu bar e Dynamic Island em execução ficaram fora desta slice e mantêm sua densidade.
Provas: `swift build`, `swift test` (452 testes), `./build.sh` e `git diff HEAD --check` verdes. Pendente de prova: inspeção visual das páginas e segmentos nos temas claro e escuro pelo operador; esta entrada não declara equivalência visual renderizada.

## Seletor de telas do atalho de brilho, 2026-10-29
Os chips de tela no atalho rápido de brilho (`UI/Workspace/QuickControlPanel.swift`) não levam rádio. O botão normal usa `border.hairline` e `fg.secondary`; o selecionado usa `selection.bg` + borda informativa `accent.solid` 1.5 px + `fg.primary` (mesmo recorte da `SettingsChoiceTile` e do `HexaSegmentControl`). Ícone de tela embutida ou externa permanece. Padding interno `Spacing.s` / `Spacing.xs`. Sem token nem primitive novo. Pares já medidos na §6: `accent.solid`/`surface.inset`, `fg.primary` e `fg.secondary` sobre `selection.bg` e `surface.inset`.
_Alterado 2026-10-29 — era: casco removido e rádio mantido. Motivo: o operador pediu o contrário: o círculo sai para ganhar espaço; a seleção vem do botão ativo versus o normal._
Provas: `swift build` verde (todos os alvos), `swift test` verde (624 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual pelo operador nos dois temas (§8), com duas e com três telas, selecionada e não selecionada, nome longo truncado.

## Segmento selecionado visível, 2026-10-29
O `Picker` nativo `.segmented` (Resolução/Tamanho do arquivo em Mídia; Compacto/Amplo/Personalizado e demais `SettingsChoiceRow`) não distinguia o ativo: o bezel do sistema com tint taupe fica quase igual ao nicho. A seleção passa pelo `HexaSegmentControl`: fundo `selection.bg`, texto `fg.primary` e borda informativa `accent.solid` 1.5 px (mesmo recorte da `SettingsChoiceTile`; par `accent.solid`/`surface.inset` já PASS na §6). Sem token novo. `SettingsChoiceRow` deixa o `Picker` segmentado e cai para menu só quando os segmentos não cabem. Pickers nativos restantes (Fan Control, Kill Process, Monitor, captura, Manter acordado) ficam fora desta fatia.
Provas: `swift build` verde (todos os alvos), `swift test` verde (624 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual pelo operador nos dois temas (§8), com 2 e com 3 segmentos, rótulo longo, foco por teclado e o fallback de menu.

## Energia e tela: vocabulário, opções e estados, 2026-11-06

O módulo `energyAndDisplay` passa a se chamar "Energia e tela" nos 15 idiomas, no lugar da metáfora "Cafeína e brilho": o título do módulo, a linha da sidebar e o painel usam os membros "Manter acordado" e "Telas". O campo interno virou `modulePowerDisplay`. A troca alinha o nome do módulo aos dois membros e ao grupo "Energia e ambiente", sem criar um terceiro vocabulário para brilho.

As duas páginas seguem o mesmo desenho: `HexaSection` com o rótulo fora do cartão. "Manter acordado" ganha o rótulo "Manter acordado" para o switch de sessão e "Opções" para o restante; "Telas" usa "Telas" e "Opções de brilho". Na página, as opções de brilho ficam visíveis (OSD, teclas seguindo o ponteiro com legenda e acesso à permissão, passos das teclas e atalhos de brilho da tela); o painel mantém o disclosure por densidade. O switch do OSD saiu do cartão principal para as opções, junto das teclas.

O controle "Escurecimento extra" para monitor DDC legível passa a ser oferecido na página (o `compact` do painel deixou de valer para ela); o painel mantém só o caminho de DDC sem leitura. "Duração padrão" volta como `Picker` de menu nas opções, mostrando o valor que os chips gravam e que o início automático usa.

A página filtra o hardware que não pode atender: "Continuar com a tampa fechada" só aparece quando existe tampa (`BrightnessService.lidClosed()` não é nil) e "Limite de bateria" só com `PowerSampler.hasInternalBattery`. O cronômetro da sessão existe uma vez, na linha de status; o chip deixou de sobrepor um segundo contador. Ao abrir "Telas", `BrightnessService.isRefreshing` alimenta um `HexaBusyState` compacto ("Lendo telas…") em vez de "Nenhuma tela encontrada". A falha de energia nomeia a tela (`displayControlFailureDisplayID`) e aparece na linha dela. Nomes duplicados de monitores recebem sufixo ordinal (" (1)", " (2)"), sem string nova.

Os switches da página usam `HexaSwitchStyle` (sessão, OSD, teclas, tampa, opções e atalhos). Os ícones de "Manter acordado" e "Telas" vêm de `AppFeature.symbolName`, iguais no painel, na sidebar e no hub. A preferência do OSD passou a valer também no slider do painel rápido. O estado de automação suprimida por parada manual é publicado e explicado no bloco de automação.

Strings novas, localizadas nos 15 idiomas: `readingDisplays` e `automationPaused`, no mesmo padrão de extensão computada já usado por `optionsTitle`. Nenhum token, primitive ou componente novo; `HexaSwitchStyle`, `HexaSection`, `HexaDisclosure`, `HexaBusyState` e `HexaStatusNote` são reusados. Pares de contraste são os já medidos na §6.

Provas: `swift build` verde (todos os alvos), `swift test` verde (639 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` assinado localmente e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual pelo operador nos dois temas (§8) das duas páginas e do painel, e, em hardware real, DDC legível e sem leitura, dois monitores idênticos, tampa, bateria, luz do teclado e VoiceOver nos switches e no escurecimento.

## Mídia: qualidade, prévia e subgrupos, 2026-11-06

A linha de qualidade das abas Vídeo e Imagem passa a usar o `HexaSegmentControl` no lugar da composição artesanal de três botões. A escala ficou discreta: o valor gravado é sempre o do nível exibido (`.low` = 0,88 "Alta", `.medium` = 0,68 "Média", `.high` = 0,28 "Baixa"), e a tela normaliza o valor gravado para o nível exibido ao aparecer. O default registrado `mediaImageQuality` passou de 0,72 para 0,68, e os presets gravam nível (Web: Média; Redes sociais: Alta; Documentos: Média). O segmento herda o contrato do primitive: selecionado com `selection.bg`, `fg.primary` e borda `accent.solid` de 1,5 px; não selecionado com `fg.secondary`, sem fill e sem borda.

A prévia da aba Imagem passou a ser produzida pelo caminho de render do serviço: `MediaService.imagePreview` reusa `makeProcessedImage`, `renderImage` e `drawWatermark`, em canvas limitado a 512 px, com margem, fonte e logo da marca d'água escalados pela proporção do canvas. A composição SwiftUI da marca d'água saiu da tela. A renderização é sob demanda: cancela-se ao sair da tela e a cada mudança de geometria, sem timer e sem cache.

O disclosure "Mais opções" da aba Imagem tem três subgrupos nomeados, nesta ordem: "Saída e metadados", "Marca d'água" e "Renomear e perfis", cada um com rótulo `SectionLabel` dentro do cartão. É uso do rótulo de seção como sub-rótulo, com precedente no painel do Desinstalador (`PanelUninstallerView`) e em Atualizações de apps (`AppUpdatesListView`). Não cria primitive nem token. `DisclosureHeaderRow` segue em uso nessa aba, dentro da isenção registrada em §7.

Acessibilidade: o slider de FPS anuncia nome (`accessibilityLabel`) e valor corrente (`accessibilityValue`). A prévia é um único elemento de imagem (`accessibilityElement(children: .ignore)` com `isImage`), cujo rótulo diz o que ela mostra; o texto visual ao lado sai da árvore de acessibilidade (`accessibilityHidden`) para não ser anunciado duas vezes.

Escopo: nenhum token, primitive, dependência ou medida nova; nenhum par de contraste novo, porque os pares usados já estão medidos em §6 nos dois temas; nenhuma cláusula `### DEC-NNN` alterada, já que esta execução não muda decisão de produto.

Provas: `swift build` verde (todos os alvos), `swift test` verde (639 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` assinado localmente e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual pelo operador nos dois temas e nos três hosts (workspace, painel da menu bar e notch), incluindo VoiceOver da linha de qualidade, do slider de FPS e da prévia. Esta entrada não declara equivalência visual renderizada.
## Dynamic Island: prévia única e cartões do notch, 2026-11-06

A aba Conteúdo da Dynamic Island passou a compor uma prévia única, `NotchPreviewStage`, em três modos: página aberta (`.page`), ilha fechada (`.resting`) e galeria de seções (`.explore`, exibida enquanto uma seção é arrastada). O editor deixou de duplicar a ilha: não existe mais mock próprio de cartões na aba Conteúdo, e a mesma superfície serve Conteúdo, Atividade e Aparência. A prévia não é interativa (`allowsHitTesting(false)`) e a leitura de sistema segue sob demanda, com a licença de monitor só enquanto a janela está visível (DEC-002). Os cards que leem hardware ou serviços ao aparecer (mixer, arquivos, watch, brilho e equalizador) respeitam `\.notchSettingsPreview` e ficam inertes na prévia; nenhum deles inicia leitura, permissão ou polling por causa dela.

O cartão interno do notch (Controles, cartões de Sistema e painel de Música) usa uma constante única, `NotchLayout.cardRadius` = 18, no lugar dos sete literais `18` que estavam em `NotchControlsView`, `NotchSystemView` e `NotchMusicView`. Ela pertence à geometria física do notch, que permanece em `NotchLayout` por DEC-017, e é a exceção de geometria por requisito funcional prevista na §4: não é token, não entra na tabela §2.2 e não cria raio paralelo ao `HexaTheme.Radius`.

O tile de seção (`NotchSectionTile`) passou a falar só com tokens semânticos: `selection.bg` quando a seção aparece e `surface.inset` quando está oculta, com `fg.primary` e `fg.secondary` no glifo. O raio é `HexaTheme.Radius.control` a partir de 20 pt de lado e `min(HexaTheme.Radius.control, lado * 0,27)` abaixo disso, para o tile pequeno continuar lendo como quadrado arredondado. A extensão `NotchModule.settingsTint`/`settingsGlyph`, que usava `border.hairline` como fundo, foi removida; as notas de §8 e §9 que a citavam como paleta própria de conteúdo ficam históricas, sem substituição de token.

Acessibilidade do cabeçalho: o `NotchSectionHeader` combina apenas o título e o resumo em um elemento; o motivo de indisponibilidade e o botão "Abrir funcionalidades" seguem como irmãos, com rótulo próprio.

Escopo: nenhum token, primitive, dependência, medida ou string de localização nova. As mudanças de produto registradas nesta execução são DEC-023, cuja opção de Reproduzindo Agora automático vive na aba Atividade, com a nota de rastro na própria cláusula, e DEC-039, que impede esconder Controles da ilha por ser a interface padrão (DEC-006).

Provas: `swift build` verde (todos os alvos), `swift test` verde (652 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` assinado localmente e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual pelo operador nos dois temas do tile em 22 e 38 pt, do raio dos cartões no notch aberto e da prévia nos três modos, incluindo VoiceOver do cabeçalho de seção.

## Popover da menu bar e painel da ilha, 2026-11-07

Registro da arquitetura real, sem mudança de comportamento nesta entrada. Nenhum código foi removido; o layout de rail permanece no código, marcado por comentário.

- **Popover da menu bar:** `QuickControlPanel` (`UI/Workspace/QuickControlPanel.swift`), 420 pt de largura. A altura é limitada à área útil da tela âncora, descontada a folga da seta; só o corpo rola, e cabeçalho e rodapé ficam fixos. Ordem: cabeçalho; "Ações rápidas", com Manter acordado primeiro (linha de largura total, com contagem regressiva de 1 s quando a sessão está ativa), depois a grade de atalhos e o brilho; "Monitoramento", com temperaturas, tiles de métricas e discos; divisória; rodapé.
- **Mixer e brilho:** o popover não tem seção de mixer nem a seção de brilho do painel da ilha. Tem uma linha de brilho em "Ações rápidas", governada por `panelQuickBrightness`. As chaves `monitorShowMixer` e `panelShowBrightness` governam somente o painel da ilha.
- **Painel da ilha:** `MenuPanelView(notchSize:)` (`UI/Notch/NotchView.swift`). O único ponto de chamada passa `notchSize`, então só o ramo `embeddedPanel` é alcançável. O layout de rail (`HexaDomainRail`, o modo rail de `HexaPanelContainer`, `MenuPanelHeader`, `navigablePanel` e `metricPanel`) não é alcançável no grafo de chamadas atual; fica no código e está marcado por comentário.
- **Vocabulário e estados:** o estado de sucesso usa o token `statusSuccess`; os rótulos de sucesso no estilo de `MaintenanceTasksView` não foram duplicados.
- **Escopo:** nenhum token, primitive, dependência ou string nova. Os pares de contraste são os já medidos em §6.
- **Entradas históricas:** "MenuPanel horizontal (Fase 2, 2026-10-07)" (§8), "painel horizontal com rail (Fase 2 do redesign minimalista, 2026-10-07)" (§9) e a nota de rail em `HexaSegmentControl` (§7) descrevem o layout de rail. Permanecem como registro histórico, não como estado atual.
- **Pendente de prova:** inspeção visual pelo operador nos dois temas, com um e com vários monitores, conteúdo longo e curto, e VoiceOver na linha de Manter acordado e nos tiles de manutenção.

Provas desta entrada: diff dos arquivos de código restrito a comentários, sem linha de código alterada; `swift build` e `git diff HEAD --check` ficam para o gate final da orquestração.

## Painel rápido em quatro faixas, 2026-11-07

O `QuickControlPanel` (`UI/Workspace/QuickControlPanel.swift`) passa de 420 pt para 600 pt de largura e reorganiza o corpo em faixas de largura total. Ordem: faixa de status; "Ações rápidas" com Manter acordado e a grade de atalhos em três colunas; brilho; e discos no rodapé do corpo. A faixa de status reúne CPU, GPU, memória, ventoinhas e bateria/energia: cada célula é um botão que abre o detalhe da métrica no workspace, com anel de foco, e a temperatura do sensor aparece na célula da métrica correspondente (CPU, GPU e bateria). O rótulo da métrica fica preso no topo da célula e o bloco de informação (valor e complemento) é centralizado na altura que sobra abaixo dele; as células dividem a mesma altura da faixa, de modo que uma célula sem complemento, como a GPU, não desça o rótulo em relação às demais. A antiga faixa de temperaturas e os tiles de métricas saem; a leitura de hardware continua a mesma, sem flag nova em `SystemMonitorPanelNeeds`. A grade de atalhos passa de duas para três colunas. O brilho volta a mostrar todos os chips de tela e o slider leva a porcentagem na mesma linha, à direita. Os discos ficam no rodapé em uma grade de até três colunas que quebra para novas linhas, com divisória hairline entre colunas e o botão de ejeção por volume preservado; a cauda cresce sem empurrar as ações. O popover segue limitado pela área útil da tela, só o corpo rola e cabeçalho e rodapé ficam fixos. Nenhum token, primitive, string ou par de contraste novo; a única medida alterada é `FeatureWorkspaceMetrics.quickWidth`, de 420 para 600.

Provas: `swift build` verde em todos os alvos, `swift test` verde (652 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` assinado localmente e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual pelo operador nos dois temas, com uma e quatro telas, dois e seis discos, e VoiceOver nas células da faixa de status e no slider de brilho.

## Limpeza: legendas informativas em caption, 2026-11-07

As legendas informativas do cartão inicial da Limpeza (`CleanerView.workspaceIdleState`) deixam o papel `micro` e adotam o primitive de legenda `hexaCaption()` (fonte `label`, cor `fgSecondary`, quebra vertical livre). Pontos alterados: `largeFilesEntry` (`largeFilesCaption`), `spaceMapEntry` e `spaceInventoryFixedBlock` (`spaceInventoryLegend`) e o estado de lista sem resultado (`largeFilesCaption`). O `micro` é IBM Plex Mono e a §3 o reserva para etiqueta de seção; usá-lo em texto corrido colocava mono em caixa baixa no corpo da página. A página de Ajustes da mesma feature já usava `label` nessas legendas. Nenhum token, primitive, string ou par de contraste novo; `fgSecondary` sobre `surface.raised` já está medido na §6 (7.32 escuro, 7.10 claro).

Fora do recorte: as legendas dos cartões de agendamento e capturas no estado compacto da Limpeza (`screenshotsCard`, `scheduleCard`) seguem em `micro`; adoção fica para uma passada própria desse painel.

Provas: `swift build` (todos os alvos), `swift test` (652 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual dos dois temas pelo operador.

## Sobre: ações padronizadas no botão de ação neutra, 2026-11-07

As quatro ações da tela Sobre (`UI/Settings/AboutSettings.swift`) usam o mesmo casco, `HexaActionButtonStyle` `.secondary` regular (altura 36, raio 6, padding horizontal 12): Refazer a configuração (`sparkles`), Baixar a versão mais recente (`download`), Apoiar no Buy Me a Coffee (`cup.and.saucer.fill`) e Acessar repositório no GitHub (`star.fill`). A ação Repositório no GitHub, que ficava no cartão de identidade, sai por duplicar o destino da ação de apoio. O link de saída Baixar a versão mais recente deixa o papel nativo de texto e passa a ser `Button` com `openURL`, e a ação de estrela do bloco de apoio deixa de pedir `controlSize(.small)`: a tela não mistura mais link de texto e botão pequeno com o botão de ação. O papel "Texto e link" da §7 continua valendo nas demais superfícies (App Updates e Desinstalador usam `.link`). Nenhum token, primitive, string ou par de contraste novo; `fg.primary` sobre `surface.inset` e sobre `selection.bg`, no normal, hover e pressionado, já está medido na §6 nos dois temas. Alvos de toque e foco por teclado são os do componente, sem exceção local. A chave `viewOnGitHub` fica sem uso no código; poda fica como limpeza separada, junto das demais chaves sem uso.

Provas: `swift build` (todos os alvos), `swift test` (652 testes, zero falhas), `./build.sh` com bundle em `build/hexa.app` assinado localmente e `git diff HEAD --check` limpo. Pendente de prova: inspeção visual dos dois temas (normal, hover, pressionado e foco por teclado nas quatro ações) pelo operador.
