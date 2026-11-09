# repo-hygiene

Normas de versionamento e higiene do repositório hexa.

## O que entra no Git

- `.app-work/` fica INTEIRO fora do Git por decisão do operador (questão `issues-visibility` respondida: `gitignored`). A linha `.app-work/` no `.gitignore` da raiz é a lei; não criar exceções para subpastas.
- `.hephaestus/` (checkpoint do kit) é efêmero e fica fora do Git; a linha no `.gitignore` é garantida pelo `apply` do kit.
- Fora do Git também: `.DS_Store`, `.build/`, `build/`, `DerivedData/`, `xcuserdata/`, `*.xcresult`.
- `.app-work/.gitignore` mantém a forma canônica do kit (`references/`, `private/`, `issues/`) mesmo com a raiz já ignorando tudo: documenta a intenção e protege se a decisão de versionamento mudar.

## Segredos, PII e terceiros

- Nunca versionar segredo, credencial, token, chave de assinatura ou PII.
- Paths de arquivo, identificadores de defaults e nomes de bundle não vazam para logs de commit.
- **Material de referência de terceiros (projetos, apps, serviços) e contexto da criação do repositório ficam EXCLUSIVAMENTE em `.app-work/references/` (fora do Git).** Nenhum arquivo versionado, commit ou histórico revela de onde o código veio, com que foi comparado ou o que inspirou decisões: a história pública do hexa começa nele mesmo.
- Exceção única (DEC-028): a atribuição exigida pela licença, ou seja, o aviso de copyright do autor original nos arquivos derivados, o texto da GPL e uma linha de atribuição no README. Comparações, números de issue de outros repositórios e o que inspirou decisões continuam fora.

## Git

- Commits somente quando o operador pedir, por chamada.
- Nunca alterar branch, histórico, stash ou remoto sem pedido explícito.
- Antes de commitar: revisar o diff staged (nada fora do recorte).
- `pauloborini/hexa` é a origem pública oficial do código-fonte GPL e começa com um commit da árvore limpa. `pauloborini/hexa-archive` é privado e preserva branches e tags de desenvolvimento, sem release nem tag de distribuição `v0.1.0`.
- Criar ou tornar público o repositório, alterar remotos ou mover histórico exige pedido explícito por operação (DEC-025, DEC-029 e DEC-042). Releases, tags de distribuição, uploads e outros destinos também exigem pedido explícito; o registro da decisão não autoriza a publicação.

## Remoções

- Antes de remoção autorizada: listar alvos, dependências e efeitos.
- Remoção derivada fora do recorte aprovado exige nova confirmação.
