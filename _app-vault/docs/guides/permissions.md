# Permissões do Sistema no Hexa

O Hexa é local-first: sem conta, sem análise e sem rastreamento (DEC-005).

Diferente de aplicativos que solicitam dezenas de autorizações indiscriminadamente na primeira inicialização, o Hexa adota o modelo de **solicitação estritamente sob demanda**: cada permissão só é requerida quando a ferramenta que depende dela é efetivamente utilizada ou ativada.

---

## 1. Princípios de Transparência e Controle

- **Tela de Boas-Vindas Inteligente (DEC-037):** Na primeira execução, o Hexa apresenta uma tela de boas-vindas própria. O usuário pode desativar qualquer módulo que não planeja utilizar. As permissões do sistema só são apresentadas para os módulos que continuarem marcados. Caso o usuário opte por recusar alguma permissão, o processo é concluído normalmente e o aplicativo degrada de forma limpa.
- **Revisão a Qualquer Momento (DEC-038):** O onboarding pode ser reiniciado quando desejado pelo botão **Refazer a configuração** em **Sobre**, respeitando o estado real de instalação de cada módulo.
- **Central de Transparência de Permissões:** Disponível em **Ajustes do Hexa > Recursos**, na aba **Permissões**, exibe:
  - O estado atual de cada permissão (Concedida, Não concedida ou Status não verificável). Arquivos e Pastas e Gerenciamento de aplicativos não têm consulta pública no macOS e aparecem sempre como não verificáveis; uma Automação cujo app de destino não está aberto também.
  - Quais módulos ativos no momento dependem de cada autorização (**Requerido por:**).
  - O botão **Solicitar** enquanto o macOS ainda aceita um pedido, e o botão **Abrir Ajustes do Sistema** no painel correspondente.
  - As três automações (Finder, Terminal e Reprodução) agrupadas numa única linha de **Automação**, com o estado de cada destino, porque o macOS as reúne num só painel dos Ajustes do Sistema.
  - Um grupo separado, **Pedidas pelo macOS no primeiro uso**, com Arquivos e Pastas, Áudio dos aplicativos e Gerenciamento de aplicativos: o Hexa não consegue pedir estas permissões antes, e o macOS pergunta na primeira vez que um recurso precisa delas.
  - A linha de Arquivos e Pastas some quando o Acesso Total ao Disco está concedido, porque ele já cobre essas pastas.
  - Aviso de permissão sem uso: quando uma permissão está concedida no macOS mas nenhum módulo ativo depende dela, a linha avisa que o acesso pode ser revogado nos Ajustes do Sistema.
- **Sem Polling em Segundo Plano (DEC-002):** A central relê os estados ao abrir e sempre que o Hexa volta ao primeiro plano. Só Acessibilidade e Gravação de Tela são reconsultadas em intervalo curto, e apenas enquanto uma tela de permissões está visível e algum módulo ativo usa uma delas (`PermissionPollingSupport`); ao fechar a tela, a consulta para. O Acesso Total ao Disco nunca é sondado em intervalo.

---

## 2. Inventário Completo de Permissões (macOS TCC)

Abaixo está o detalhamento de todas as permissões de sistema utilizadas pelo Hexa, seus módulos requerentes, justificativa técnica e impacto caso não sejam autorizadas:

| Permissão do macOS | Módulos Requerentes | Justificativa Técnica | Momento da Solicitação | Comportamento se Negada |
|---|---|---|---|---|
| **Acessibilidade** | Mixer, Brilho de tela, Dynamic Island (indicadores de volume, brilho e luz do teclado; Notificações), Keep Awake, Dock em uma tela, Ícones da menu bar | Permite o volume mais preciso no controle do Mixer, as teclas e o indicador de brilho, os indicadores e a leitura das notificações do sistema na ilha, o movimento leve do cursor do Keep Awake, a leitura da posição do Dock com o recuo do ponteiro e a leitura dos itens da menu bar. Os atalhos globais não dependem dela. | Ao ligar a opção que depende dela (volume mais preciso, teclas ou indicador de brilho, Dock em uma tela, Ícones da menu bar) ou pelo botão de solicitar exibido na opção, como em **Mover cursor levemente** e nos ajustes da Dynamic Island. | Só a opção correspondente deixa de funcionar: o Dock não é mantido na tela, nenhum item da menu bar é escondido, a ilha não mostra esses indicadores nem as notificações; demais funções operam normalmente. |
| **Gravação de Tela** | Captura de Tela, OCR de Tela, Dynamic Island (Observar) | Permite obter a imagem de janelas e áreas do monitor para a ferramenta de captura, para o reconhecimento óptico de caracteres via Vision e para a leitura da área escolhida em Observar. | No primeiro acionamento de captura de tela ou OCR, ou ao escolher a área em Observar. | A captura e o OCR não iniciam e o Hexa volta a pedir a permissão; Observar não permite escolher a área. |
| **Acesso Total ao Disco** | Cleaner, Uninstaller | Permite que o desinstalador e o limpador localizem caches órfãos e arquivos residuais dentro de diretórios protegidos (`~/Library/Containers`, etc.). | Opcional. Não existe pedido do sistema: o botão **Conceder acesso…** registra o Hexa na lista e abre Ajustes do Sistema > Privacidade e Segurança, onde o usuário ativa o Hexa. O acesso só vale depois de reabrir o app. | O aplicativo continua funcionando normalmente, mas a varredura atua apenas nas pastas comuns do usuário. |
| **Arquivos e Pastas** | Captura de Tela, Cleaner, Dynamic Island (Downloads) | Permite salvar capturas de tela diretamente em pastas como Mesa (Desktop) ou Documentos, acompanhar downloads e limpar itens em pastas que o macOS protege. | Pedida pelo próprio macOS no primeiro acesso a uma pasta protegida (salvamento de captura, varredura de limpeza ou leitura da pasta de downloads). | A captura não é salva e o Hexa avisa que não foi possível salvar na pasta; as pastas protegidas ficam fora do alcance do Cleaner e da ilha. |
| **Notificações** | Keep Awake, Dynamic Island (Observar), Cleaner | Envia alertas operacionais na conclusão de tarefas (fim de uma sessão do Keep Awake com duração, aviso de Observar quando a ilha não pode aparecer, término da limpeza agendada). | Ao iniciar manualmente uma sessão do Keep Awake com duração, na primeira observação de Observar ou ao habilitar o aviso da limpeza agendada. | As tarefas são concluídas normalmente, porém sem avisos visuais no Centro de Notificações do macOS. |
| **Automação do Finder** | Cleaner, Uninstaller | Comunica-se com o Finder nativo para enviar à Lixeira os itens que a Lixeira comum não conseguiu mover, sem comandos perigosos de terminal. | Na primeira vez que uma remoção no Cleaner ou no Desinstalador precisa recorrer ao Finder, ou pelo botão **Solicitar** na central. | Os itens que a Lixeira comum não moveu permanecem no lugar e são informados como não removidos. |
| **Automação do Terminal** | App Updates, Uninstaller | Quando um comando do Homebrew exige a senha de administrador, o Hexa abre o Terminal com o comando para que o usuário digite a senha ali. O Hexa não captura senhas. | Ao escolher abrir o Terminal depois que uma atualização ou desinstalação via Homebrew pediu a senha de administrador. | O Terminal não é aberto pelo app e a operação que exige a senha não pode ser concluída pelo Hexa. |
| **Automação de Reprodução** | Dynamic Island | Envia comandos de mídia (play, pause, próxima faixa) por Apple Events aos reprodutores que exigem essa permissão; o acesso é concedido separadamente para cada app. | Ao tocar em **Permitir controle da reprodução** na ilha com o reprodutor aberto. | Os controles de mídia da ilha ficam indisponíveis para aquele reprodutor. |
| **Áudio dos aplicativos** | Dynamic Island (Barras seguem a música), Mixer | Lê o áudio de saída de cada app para que o Mixer ajuste o volume por aplicativo e para que as barras do equalizador da ilha acompanhem a música. O áudio nunca é gravado. | Pedida pelo próprio macOS no primeiro ajuste de volume de um app no Mixer ou na primeira música com **Barras seguem a música** ligado. | O Mixer não ajusta o volume por app e indica como liberar nos Ajustes do Sistema; as barras da ilha mantêm a animação decorativa, sem seguir o áudio. |
| **Gerenciamento de aplicativos** | App Updates | Permite que as atualizações substituam ou desinstalem aplicativos gerenciados por pacote na pasta `/Applications`. | Pedida pelo próprio macOS na primeira vez que uma atualização precisa alterar um app instalado. | O macOS impede a alteração do aplicativo e a atualização dele não é concluída. |
| **Calendário** | Dynamic Island (Calendário) | Permite leitura estritamente local dos eventos e reuniões do dia na base do aplicativo Calendário da Apple. | Ao tocar em **Permitir acesso ao calendário** na seção de Calendário da Dynamic Island. | A seção de calendário do entalhe exibe uma mensagem indicando ausência de autorização de leitura. |
| **Bluetooth** | Monitor de Sistema (Energia), Dynamic Island (Avisos de acessórios) | Consulta o nível de carga da bateria de periféricos sem fio conectados (AirPods, Magic Mouse, fones Bluetooth compatíveis). | Ao tocar em **Mostrar bateria de acessórios Bluetooth** na área de Energia do Monitor, ou pelo botão **Solicitar** na central. | A lista de dispositivos exibe apenas as informações gerais que o macOS provê sem comunicação direta via Bluetooth. |

---

## 3. Como Gerenciar ou Revogar Permissões

Você mantém o controle total sobre as permissões concedidas ao Hexa. Para consultar ou revogar qualquer autorização:

1. Abra os **Ajustes do Sistema** do macOS.
2. Navegue até o menu lateral **Privacidade e Segurança**.
3. Selecione a categoria correspondente (por exemplo, *Acessibilidade*, *Gravação de Tela* ou *Acesso Total ao Disco*).
4. Localize o **Hexa** na lista de aplicativos e desative o seletor correspondente.
5. Ao retornar ao Hexa, o aplicativo relê o estado das permissões automaticamente e atualiza os módulos sem necessidade de intervenção manual. A exceção é o Acesso Total ao Disco: uma concessão só passa a valer depois de reabrir o app.
