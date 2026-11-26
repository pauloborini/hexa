# uninstaller

Affects: [uninstaller]

### DEC-009 — Seleção padrão com atalho selecionar tudo

Por padrão, nada vem pré-selecionado na lista de sobras. A única adição é o atalho "selecionar tudo" na lista de sobras, seguindo o padrão do selectAll() da lista de updates.

### DEC-052 — Desinstalação em lote por seleção explícita de apps

O Uninstaller aceita vários apps na mesma seleção manual, pelo seletor ou por arrastar e soltar. A varredura continua sob demanda e agrega as sobras sem pré-selecionar nada; cada item mantém a associação ao app de origem. A remoção continua exigindo escolha explícita e preserva por app as regras de identidade, propriedade de dados, apps em execução, aliases e pacotes Homebrew. Pacotes Homebrew selecionados no mesmo lote são removidos em uma única operação `brew uninstall --cask`, com confirmação própria.
