# Versionamento

Affects: [app-updates, monitor, uninstaller, cleaner, maintenance-tasks, media-tools, dynamic-island, mixer, keep-awake, keyboard-light, screen-brightness, kill-process, port-manager, screen-capture]

### DEC-019 — Primeira versão pública beta

A primeira entrega pública do hexa usa `0.1.0` (versão estável, sem fase ou sufixo beta), com fonte única em `Sources/Hexa/Resources/ReleaseVersion.txt`. As funcionalidades nascem completas e estáveis diretamente na versão estável. A tag de publicação correspondente é `v0.1.0`. Definir a versão não autoriza criar tag, enviar artefatos ou publicar.
_Alterado 2026-10-11 — era: primeira versão com sufixo beta (0.1.0-beta) e pré-release. Motivo: operador determinou que cada versão deve ser tecnicamente estável e sem fase beta, com distribuição direta._

### DEC-043 — Smoke de release em uma máquina Apple Silicon
O smoke de cada release é executado em uma única máquina macOS arm64 disponível ao mantenedor. Não há matriz por geração de chip nem requisito de ensaio em chip fora do mapa. O registro cobre os fluxos definidos no contrato de release e não afirma que cada recurso específico de hardware foi exercitado em todas as gerações.
