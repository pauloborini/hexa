# design-system

Norma de consumo do design system do hexa. Produto vigente: DEC-017 (design system próprio) e DEC-011 (identidade própria), em `_app-vault/docs/decisions/licenca-e-identidade.md`. Registro canônico de valores e contratos: `_app-vault/specs/design-system.md` — esta regra normatiza o COMO, sem duplicar valores.

## Consumo de tokens

- View em `Sources/Hexa/UI/` consome tokens semânticos (camada de tema em `Support/` ou `Core/`); proibido literal de cor, fonte, tamanho, raio ou espaçamento na view quando existe papel semântico para ele.
- Três camadas: base → semântico → componente. Componente nunca consome base direta; camada de componente só existe com contrato estável de primitive.
- Token novo exige papel que o vocabulário atual não atende; registrar na spec antes do uso. Variação estética local não cria token.

## Primitives

- Reusar os primitives canônicos (`HairlineDivider`, `SectionLabel`, `DataRow`, `PanelHeader`) onde o contrato atende; a composição local de domínio é legítima e não vira primitive por semelhança visual.
- Promoção de primitive novo exige dois consumidores reais ou transversalidade comprovada, comparando anatomia, variantes, medidas, estados, foco e acessibilidade. Contrato registrado na spec.

## Contraste

- Par foreground/background novo ou alterado (texto, ícone, foco, borda informativa, status): medir contra WCAG 2.1 AA (4.5:1 texto, 3:1 não-texto) sobre a superfície real de uso, por tema e estado, e registrar na matriz da spec. Par reprovado não entra.
- Exceção é nominada, justificada e delimitada na spec; não se estende a outros papéis, temas ou superfícies.

## Gates

- Falha bloqueante no boundary de UI: literal onde o contrato exige token, par de contraste reprovado, foco inacessível, quebra do contrato de primitive canônico.
- Mudança que afeta aparência ou usabilidade: gate estrutural + inspeção visual dos temas, estados e contextos afetados (matriz na spec, §8). Gate estático verde não declara equivalência visual.
- Adoção de tokens é por superfície, dentro das slices do roadmap; sem rewrite global e sem mudança de comportamento fora do recorte. Cobertura registrada na spec (§9).
