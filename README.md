# hexa

O utilitário definitivo para a barra de menus do macOS: ferramentas essenciais do escopo reunidas em um único aplicativo nativo, leve e elegante.

[![Licença: GPL-3.0-or-later](https://img.shields.io/badge/licen%C3%A7a-GPL--3.0--or--later-blue.svg)](LICENSE)
[![Plataforma: macOS](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma%2FSequoia)-black.svg)](https://apple.com/macos)
[![Arquitetura: Apple Silicon](https://img.shields.io/badge/arquitetura-Apple%20Silicon%20(arm64)-orange.svg)](#requisitos-de-sistema)
[![Privacidade: 100% Local-First](https://img.shields.io/badge/privacidade-100%25%20local--first-success.svg)](#diretrizes-fundamentais)
[![Eficiência: Zero Polling](https://img.shields.io/badge/amostragem-100%25%20sob%20demanda-brightgreen.svg)](#diretrizes-fundamentais)

O **hexa** foi construído em Swift e SwiftUI para substituir múltiplos aplicativos dispersos de manutenção, monitoramento e produtividade. Ele oferece uma experiência integrada em janela única, combinando utilitários do dia a dia com alto desempenho e sem rotinas em segundo plano quando não está em uso.

---

## Diretrizes Fundamentais

O hexa segue três pilares de engenharia estritos e sem concessões:

1. **100% Sob Demanda (Zero Polling) [DEC-002]:**
   Ao contrário dos utilitários tradicionais que mantêm dezenas de timers e processos em segundo plano drenando bateria silenciosamente, o hexa realiza leituras estritamente sob demanda. Métricas de CPU, GPU, temperatura, memória e rede só são amostradas enquanto o painel correspondente estiver aberto na tela, ou enquanto você mantiver uma leitura compacta ligada na barra de menus (DEC-003). As poucas exceções, como a sessão do Fan Control e as extensões ativas da Dynamic Island, estão nomeadas no DEC-002 e no [guia de arquitetura](_app-vault/docs/guides/architecture.md).

2. **100% Local-First e Privado [DEC-005]:**
   Zero telemetria, zero rastreamento, zero analytics e sem criação de contas. Seus dados, processos, arquivos inspecionados e rotinas nunca saem do seu computador.

3. **Exclusivo para Apple Silicon [DEC-027]:**
   Projetado desde o primeiro dia exclusivamente para os processadores Apple Silicon (M1 a M4 e superiores). Sem código legado de arquitetura Intel, aproveitando aceleração de hardware nativa, sensores térmicos integrados e chamadas diretas ao SMC.

---

## Módulos

O hexa organiza suas ferramentas em uma janela única com barra lateral unificada e alternância rápida entre **Operação** e **Ajustes** no cabeçalho de cada módulo (DEC-014).

| Módulo | Resumo Operacional | Diferencial Técnico |
|---|---|---|
| **App Updates** | Atualização de apps da Mac App Store, Homebrew Casks e ferramentas de CLI. | Execução sob demanda via processos isolados; sem Homebrew instalado, a fonte Homebrew fica silenciosa, sem alertas recorrentes (DEC-004). |
| **Monitor de Sistema** | Telemetria em tempo real de CPU, GPU, RAM, disco, rede, sensores de bateria e Fan Control. | Amostragem estritamente vinculada à visibilidade do painel; leituras compactas na menu bar são opcionais (DEC-003). |
| **Uninstaller** | Desinstalação completa de aplicativos com varredura profunda de arquivos residuais. | Inspeciona Application Support, Caches, Containers, Preferences e Logs com atalho "Selecionar Tudo". |
| **Cleaner + Manutenção** | Limpeza de caches do sistema, logs, sobras, conversas do Claude Code e rotinas de manutenção. | Inclui conversas antigas do Claude Code (`~/.claude/projects`, DEC-020), flush DNS com autenticação nativa (DEC-035) e purge de RAM. |
| **Media Tools** | Compressor de vídeo e de imagem, criador de GIFs e extrator de texto por OCR. | Processamento local acelerado por AVFoundation, ImageIO e Vision no Apple Silicon. |
| **Dynamic Island** | Central de interação no entalhe físico (notch) dos MacBooks com widgets modulares. | Controles rápidos como interface padrão (DEC-006), dimensão exata do notch (DEC-007) e grade fixa de atalhos (DEC-008). |
| **Mixer por App** | Ajuste independente de volume para cada aplicativo aberto no sistema operacional. | Opera diretamente via CoreAudio sem instalar extensões de kernel (kexts) ou drivers de terceiros. |
| **Keep Awake** | Prevenção de suspensão do sistema, desligamento de tela e automações inteligentes. | Suporte a operação com tampa fechada (clamshell), automação por monitor externo, fonte de energia ou app em execução e piso de bateria (DEC-034). |
| **Luz do Teclado** | Controle da intensidade da retroiluminação do teclado integrado do Mac. | Ajuste contínuo por controle deslizante e atalhos, na mesma tela do Brilho. |
| **Brilho de Tela** | Central de controle para telas integradas e múltiplos monitores externos. | Suporte a protocolo DDC/CI para telas externas e atenuação por software (software dimming) abaixo do mínimo (DEC-013). |
| **Kill Process + Port Manager** | Monitor e encerramento forçado de processos e liberação imediata de portas de rede. | Mapeia instantaneamente portas TCP em escuta e encerra o processo associado para liberar a porta em um clique. |
| **Dock em uma tela** | Mantém o Dock fixo na tela escolhida quando há vários monitores. | Impede que o Dock vá para outra tela quando o ponteiro chega à borda; segure Option para movê-lo de propósito. |
| **Ícones da menu bar** | Oculta os ícones de outros apps à esquerda do chevron e revela com um clique. | Recolhe de novo após o prazo escolhido (Instantâneo, 5 s ou 10 s); os itens do próprio macOS ficam sempre visíveis (DEC-041). |
| **Captura de Tela + OCR** | Captura em área, janela ou tela inteira com editor de anotações e leitura óptica de texto. | Salvamento automático configurável (DEC-030), prévia opt-in (DEC-024) e OCR ultrarrápido com Apple Vision. |

---

## Requisitos de Sistema

- **macOS:** 14.0 (Sonoma) ou superior (incluindo macOS 15 Sequoia).
- **Processador:** Apple Silicon (M1, M2, M3, M4 ou superiores). Macs com processadores Intel não são suportados.
- **Permissões:** Concedidas estritamente sob demanda conforme o uso de cada módulo.

---

## Instalação

### Opção 1: Download Direto da Imagem de Disco (DMG) - Recomendado

Baixe a versão estável mais recente diretamente na página de lançamentos do projeto:

1. Acesse as [Releases no GitHub](https://github.com/pauloborini/hexa/releases).
2. Baixe o arquivo `hexa-<versão>-arm64.dmg`.
3. Abra a imagem de disco e arraste o **Hexa** para a pasta **Aplicativos**.

### Opção 2: Homebrew Cask

Se você utiliza o gerenciador de pacotes Homebrew:

```bash
brew tap pauloborini/hexa https://github.com/pauloborini/hexa
brew install --cask hexa
```

### Opção 3: Compilação a partir do Código-Fonte

Clone o repositório e monte o bundle oficial com o script de automação:

```bash
git clone https://github.com/pauloborini/hexa.git
cd hexa
./build.sh --release
```

O aplicativo compilado e assinado localmente estará disponível em `build/hexa.app`. É preciso Xcode 16 ou superior e uma identidade de assinatura no Keychain; no macOS 27, o módulo Ícones da menu bar só funciona em build assinado com Developer ID. Detalhes no [guia de compilação](_app-vault/docs/guides/building.md).

---

## Transparência de Permissões

O hexa adota um modelo de **solicitação estritamente sob demanda**: cada permissão só é pedida quando o módulo que depende dela é usado, e a tela de boas-vindas só apresenta as permissões dos módulos que você manteve (DEC-037). Você pode verificar o estado de cada permissão em **Recursos > Permissões**:

| Permissão | Módulos Requerentes | Finalidade Principal |
|---|---|---|
| **Acessibilidade** | Mixer, Brilho, Dynamic Island, Keep Awake, Dock em uma tela, Ícones da menu bar | Ajuste de volume por app, controle de luminosidade, posição do Dock e ocultação dos ícones da barra de menus. |
| **Gravação de Tela** | Captura de Tela, OCR de Tela, Dynamic Island (Watch) | Captura de janelas, monitoramento de áreas do display e reconhecimento visual de texto. |
| **Acesso Total ao Disco** | Cleaner, Uninstaller | Localização e remoção de arquivos residuais e caches em diretórios protegidos (opcional). |
| **Arquivos e Pastas** | Captura de Tela, Cleaner, Dynamic Island (Downloads) | Gravação direta de capturas na Mesa ou Documentos e acompanhamento de downloads. |
| **Notificações** | Keep Awake, Dynamic Island (Observar), Cleaner | Avisos operacionais de conclusão de timers e término de rotinas de limpeza. |
| **Automação (Finder, Terminal e reprodutores)** | Cleaner, Uninstaller, App Updates, Dynamic Island | Lixeira via Finder quando a remoção comum falha, comandos do Homebrew no Terminal quando pedem senha e controle de reprodução de players. |
| **Áudio dos Aplicativos** | Dynamic Island (Equalizador), Mixer | Volume independente por app no Mixer e visualizador de áudio na ilha. |
| **Gerenciamento de Apps** | App Updates | Atualização de aplicativos instalados em `/Applications`. |
| **Bluetooth** | Monitor de Sistema (Energia), Dynamic Island (Acessórios) | Consulta de carga da bateria de periféricos sem fio (AirPods, teclados e mouses). |
| **Calendário** | Dynamic Island (Calendário) | Leitura estritamente local dos próximos compromissos e eventos do dia. |

Para um detalhamento completo de cada permissão, acesse o [Guia de Permissões](_app-vault/docs/guides/permissions.md).

---

## Documentação

Explore a documentação técnica detalhada na pasta `_app-vault/docs/guides/`:

- [**Arquitetura do Hexa**](_app-vault/docs/guides/architecture.md): Princípio zero-polling, arquitetura de janela única, comunicação XPC e piso de segurança térmica do Fan Control.
- [**Guia Completo dos Módulos**](_app-vault/docs/guides/modules.md): Funcionamento aprofundado, atalhos de teclado e configurações de cada módulo.
- [**Inventário de Permissões**](_app-vault/docs/guides/permissions.md): Relação completa das autorizações do macOS TCC, justificativas técnicas e passos para concessão ou revogação.
- [**Compilação e Desenvolvimento**](_app-vault/docs/guides/building.md): Estrutura de alvos do `Package.swift`, compilação via SwiftPM, script `build.sh` e probes de depuração.

---

## Licença e Atribuição

Distribuído sob a licença **GPL-3.0-or-later**. Consulte o arquivo [LICENSE](LICENSE) para o texto integral dos termos legais.

Copyright (C) 2026 Paulo Borini. O hexa possui identidade própria (nome, marca, design system e interface gráfica).

O hexa é obra derivada do [Vorssaint](https://github.com/vorssaint/vorssaint-utils) (Copyright (C) 2026 Vorssaint), modificada por Paulo Borini a partir de 2026 e distribuída sob GPL-3.0-or-later, sem afiliação nem endosso do projeto de origem (DEC-028).
