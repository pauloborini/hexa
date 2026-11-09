# Guia de Compilação e Desenvolvimento

Este guia descreve os requisitos de ambiente, a estrutura de alvos do SwiftPM e os passos para compilar e testar o **Hexa** localmente no macOS.

---

## 1. Requisitos de Ambiente

Para compilar o Hexa a partir do código-fonte, certifique-se de atender aos seguintes pré-requisitos:

- **Sistema Operacional:** macOS 14.0 (Sonoma) ou superior.
- **Hardware:** Computador Mac com chip Apple Silicon (M1, M2, M3, M4 ou superiores). O Hexa não suporta processadores Intel (DEC-027).
- **Ferramentas de Desenvolvimento:**
  - Xcode 16 ou superior, ou Command Line Tools equivalentes (`xcode-select --install`). O manifesto declara `swift-tools-version:5.9`, mas o código usa APIs do SDK do macOS 15 (por exemplo `onScrollGeometryChange`), que não existem no Xcode 15.
  - Python 3 para o `build.sh` (o `python3` do macOS basta). Os scripts de DMG (`scripts/release/prepare_dmg.py`) exigem Python 3.11 ou superior e os módulos de `scripts/release/requirements.txt`.
  - Uma identidade de assinatura de código no Keychain com Team ID (por exemplo, Apple Development ou Developer ID Application). Sem ela o `build.sh` falha (seção 4).
  - Gitleaks, só para o build de release (`scripts/release/build-release.sh`).

O comando `scripts/release/check-secrets.sh`, chamado pelo `build-release.sh`, verifica o histórico Git e os
arquivos da árvore atual antes do build de release. O gate falha se o Gitleaks
estiver ausente ou encontrar um segredo; investigue a ocorrência sem publicar
seus valores. Arquivos `.env.example` devem conter somente exemplos.

---

## 2. Estrutura de Alvos do Swift Package Manager

O projeto é gerenciado de forma nativa através do `Package.swift`, estruturado em alvos independentes para modularidade e separação de privilégios:

```
Alvos do Package.swift
├── Hexa (Executable Target)
│   ├── VMStatisticsCompat (System Library Target)
│   ├── FanControlCore (Library Target)
│   └── NotchPlaybackCore (Library Target)
├── FanControlHelper (Executable Target)
│   └── FanControlCore (Library Target)
├── NowPlayingAdapter (Dynamic Library Target)
│   └── NotchPlaybackCore (Library Target)
└── hexaTests (Test Target)
    ├── Hexa
    └── FanControlCore
```

### Detalhamento dos Alvos

- **`Hexa`:** O executável principal do aplicativo. Contém a interface do usuário em SwiftUI, o controlador de barra de menus (menu bar), gerenciamento de preferências e os serviços dos módulos.
- **`FanControlHelper`:** Executável auxiliar e isolado, responsável por interagir diretamente com o Apple Silicon SMC para leitura de sensores de temperatura e ajuste de rotação das ventoinhas via protocolo XPC seguro.
- **`FanControlCore`:** Biblioteca estática compartilhada entre o aplicativo principal e o helper, contendo estruturas de dados, limites de segurança térmica e protocolos de comunicação.
- **`NotchPlaybackCore`:** Biblioteca compartilhada com a lógica de controle de mídia e comunicação de reprodução para a Dynamic Island.
- **`NowPlayingAdapter`:** Biblioteca dinâmica (`.dylib`) que encapsula o acesso às informações de reprodução de áudio do sistema operacional sem acoplar bibliotecas privadas ao executável principal. Não é linkada ao app: o `Resources/now-playing.pl` a carrega via `/usr/bin/perl` e o app lê a resposta em JSON.
- **`VMStatisticsCompat`:** Biblioteca em linguagem C que acessa diretamente chamadas Mach do kernel (`host_statistics64`) para coleta precisa de métricas de memória física, swap e compressão.
- **`hexaTests`:** Suíte de testes automatizados de unidade cobrindo regras de negócio, limites térmicos, parsing de métricas e ciclo de vida dos módulos.

---

## 3. Compilação via SwiftPM (Linha de Comando)

Para compilar rapidamente os binários durante o desenvolvimento:

### Modo Debug (Desenvolvimento)
```bash
swift build
```

### Modo Release (Otimizado)
```bash
swift build -c release
```

### Executar a Suíte de Testes
```bash
swift test
```

---

## 4. Montagem Completa do Aplicativo (`build.sh`)

O Hexa inclui um script de automação de compilação e montagem do pacote de aplicativo (`.app`), localizado na raiz do repositório: `build.sh`.

O script realiza as seguintes etapas automaticamente:
1. Compila todos os alvos do pacote em modo Debug (padrão ou `--debug`) ou Release (`--release`).
2. Monta a árvore canônica do bundle do macOS em `build/hexa.app/`:
   - `Contents/MacOS/Hexa`: Executável principal.
   - `Contents/MacOS/FanControlHelper`: Executável do helper do Fan Control.
   - `Contents/Frameworks/libNowPlayingAdapter.dylib`: Biblioteca dinâmica do reprodutor.
   - `Contents/Library/LaunchDaemons/<bundle id>.fan-control.plist`: Serviço Mach que ativa o helper sob demanda, sem `RunAtLoad`.
   - `Contents/Resources/now-playing.pl`: Ponte que carrega a dylib do reprodutor.
   - `Contents/Resources/hexa_Hexa.bundle`: Recursos de fontes (Instrument Serif, Manrope, IBM Plex Mono), ícones Lucide e marca.
   - `Contents/Resources/AppIcon.icns`: Ícone oficial do aplicativo.
   - `Contents/Resources/LICENSE`, `CHANGELOG.md` e `*.lproj/InfoPlist.strings`: Texto da licença, notas da versão e textos de permissão localizados.
   - `Contents/Info.plist`: Metadados com carimbo de commit e identificadores de versão.
3. Aplica assinatura de código local (*codesign*) com uma identidade de assinatura do Keychain do macOS. A identidade precisa ter Team ID: assinatura ad-hoc não autentica o FanControl e o script falha sem ela. O script procura primeiro as identidades do Team ID padrão do mantenedor; sem correspondência, usa a única identidade de assinatura disponível e falha se houver mais de uma. `HEXA_CODESIGN_IDENTITY` força a identidade e `HEXA_CODESIGN_TEAM_ID` define o Team ID procurado, por exemplo:
   ```bash
   HEXA_CODESIGN_TEAM_ID=<TEAM_ID> ./build.sh
   ```

> **Assinatura e Ícones da menu bar no macOS 27:** no macOS 27 o módulo Ícones da menu bar só ativa quando o app está assinado com um certificado **Developer ID Application**; com outra identidade (por exemplo, Apple Development) ele aparece como indisponível. O `build.sh` não prefere Developer ID: para testar esse módulo no macOS 27, force a identidade com `HEXA_CODESIGN_IDENTITY=<IDENTIDADE_DEVELOPER_ID>`. A prévia de DMG (seção 5) já prefere Developer ID quando ele existe no Keychain.

### Comandos de Utilização

- **Montar aplicativo para depuração local:**
  ```bash
  ./build.sh
  ```
  Gera o pacote em `build/hexa.app`.

- **Montar versão de distribuição final (Release):**
  ```bash
  ./build.sh --release
  ```

- **Executar a suíte de testes:**
  ```bash
  ./build.sh --test
  ```

- **Montar versão de testes e probes de apresentação:**
  ```bash
  ./build.sh --probe
  ```
  Compila em Debug com `-DHEXA_DEVELOPMENT`, gera `build/hexa-probe.app` com o identificador de desenvolvimento `io.github.pauloborini.hexa.dev` (DEC-026) e, ao final, executa os quatro probes da seção 6.

---

## 5. Geração de DMG local

Os scripts de `scripts/release/` montam um DMG arm64 (DEC-027) sem criar tag, notarizar ou publicar. Todos gravam em `.app-work/releases/`, pasta criada pelos próprios scripts e ignorada pelo Git.

```bash
./build.sh --release                      # bundle base em build/hexa.app
scripts/release/build-release.sh          # gate de segredos + produtos arm64 com proveniência
scripts/release/generate-artwork.sh       # ícone e fundo do DMG
python3 -m pip install -r scripts/release/requirements.txt
python3 scripts/release/prepare_dmg.py --app build/hexa.app --preview
```

- Se o seu Python bloquear instalação global de pacotes, instale os requisitos em um ambiente virtual (`python3 -m venv`).
- `--preview` gera `hexa-PREVIEW-arm64.dmg`, aceita árvore com mudanças locais e identidade de desenvolvimento, mas prefere Developer ID Application quando ele existe no Keychain.
- Sem `--preview` (distribuição), o script exige `--build 1..9999`, árvore limpa, branch `main` e assinatura Developer ID Application com hardened runtime; o arquivo sai como `hexa-<versão>-arm64.dmg`. A versão vem de `Sources/Hexa/Resources/ReleaseVersion.txt`.
- `--identity` (ou `HEXA_RELEASE_IDENTITY`) escolhe a identidade quando há mais de uma candidata.
- Os produtos precisam corresponder ao commit e às fontes atuais; após qualquer mudança, rode `build-release.sh` de novo.

Notarização e publicação (`notarize.py`, `publish.py`) são etapas do mantenedor e exigem credenciais próprias.

---

## 6. Depuração e Probes de Teste

### Logs em Tempo Real
O Hexa utiliza o sistema unificado de logs do macOS (`os.log`). Para acompanhar a emissão de logs durante a depuração:

```bash
log stream --predicate 'subsystem == "io.github.pauloborini.hexa"' --level debug
```

O subsystem é o bundle identifier: no build `--probe` use `io.github.pauloborini.hexa.dev`; o helper do Fan Control registra em `<bundle id>.fan-control`.

### Testes de Apresentação (Ajustes e Dynamic Island)
Após compilar a versão de teste com `./build.sh --probe`, é possível acionar de novo os modos de diagnóstico pelo terminal. As flags só existem em builds com `HEXA_DEVELOPMENT`:

```bash
# Teste de apresentação da janela de Ajustes
build/hexa-probe.app/Contents/MacOS/Hexa --settings-presentation-test

# Teste geral de apresentação do notch
build/hexa-probe.app/Contents/MacOS/Hexa --notch-presentation-test

# Teste de cliques e navegação na barra de atalhos rápidos
build/hexa-probe.app/Contents/MacOS/Hexa --notch-presentation-test --quick-access-clicks

# Teste do layout de mídia e controles de reprodução
build/hexa-probe.app/Contents/MacOS/Hexa --notch-presentation-test --media-layout
```

---

## 7. Diretrizes para Contribuição

- **Sem Dependências Externas Pesadas:** O `Package.swift` não declara dependências de pacotes; o Hexa utiliza apenas recursos de código aberto embutidos (fontes e ícones) e frameworks nativos da Apple. Evite introduzir dependências externas de pacotes de terceiros.
- **Respeito ao Princípio On-Demand:** Qualquer nova função ou melhoria deve respeitar a DEC-002: painéis e scans só rodam quando abertos ou pedidos, sem polling, timers automáticos ou alertas em fundo, salvo as exceções nominadas na própria decisão.
- **Privacidade Local-First:** Sem telemetria, análise, rastreamento ou conta de usuário (DEC-005).
- **Validação antes de entregar:** `swift build` com todos os alvos compilando, `swift test` quando a mudança tocar código com testes e `git diff HEAD --check` sem erros.
