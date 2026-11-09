#!/bin/bash
# build.sh - distribuição LOCAL do hexa (slice M8, FECHAMENTO-001).
#
# Monta build/hexa.app a partir do pacote SwiftPM: executável Hexa +
# FanControlHelper + dylib da ponte do player (libNowPlayingAdapter) +
# recursos (hexa_Hexa.bundle com as fontes OFL e a marca, AppIcon.icns).
# Assinatura local com identidade válida do Keychain para autenticação XPC.
# Nada sai da máquina: sem push, release, upload ou notarização.
#
# Uso:
#   ./build.sh             # build Debug + bundle
#   ./build.sh --release   # build Release + bundle
#   ./build.sh --test      # roda a suíte de testes (swift test) e nada mais
#   ./build.sh --probe     # bundle separado com HEXA_DEVELOPMENT + três probes
#
# Probes (após --probe, identidade io.github.pauloborini.hexa.dev):
#   build/hexa-probe.app/Contents/MacOS/Hexa --notch-presentation-test
#   build/hexa-probe.app/Contents/MacOS/Hexa --notch-presentation-test --quick-access-clicks
#   build/hexa-probe.app/Contents/MacOS/Hexa --notch-presentation-test --media-layout
#
# O carimbo do AppInfo (Sources/Hexa/Core/AppInfo.swift) é lido daqui:
#   HexaBuildCommit          "<sha>[-dirty] · <data>"
#   HexaFanControlHelperVersion  mesma versão curta do helper
set -euo pipefail
cd "$(dirname "$0")"

CONFIG=debug
PROBE=false
case "${1:-}" in
  --release) CONFIG=release ;;
  --probe) PROBE=true ;;
  --debug|-debug) CONFIG=debug ;;
  --test|-test)
    exec swift test
    ;;
  "")
    ;;
  *)
    echo "uso: ./build.sh [--debug|--release|--test|--probe]" >&2
    exit 2
    ;;
esac

# bash 3.2 do macOS não tem ${var^}: capitaliza à mão (debug → Debug).
CONFIG_DIR="$(python3 -c "import sys; print(sys.argv[1].capitalize())" "$CONFIG")"
PRODUCTS=".build/out/Products/$CONFIG_DIR"
APP="build/hexa.app"
BUNDLE_ID="io.github.pauloborini.hexa"
if [ "$PROBE" = true ]; then
  APP="build/hexa-probe.app"
  BUNDLE_ID="io.github.pauloborini.hexa.dev"
fi
HELPER_ID="$BUNDLE_ID.fan-control"
CONTENTS="$APP/Contents"

echo "==> swift build -c $CONFIG (todos os alvos)"
if [ "$PROBE" = true ]; then
  swift build -c "$CONFIG" -Xswiftc -DHEXA_DEVELOPMENT
else
  swift build -c "$CONFIG"
fi

BINARY="$PRODUCTS/Hexa"
HELPER="$PRODUCTS/FanControlHelper"
DYLIB="$PRODUCTS/libNowPlayingAdapter.dylib"
RESOURCES_BUNDLE="$PRODUCTS/hexa_Hexa.bundle"
ICNS="Sources/Hexa/Resources/Brand/AppIcon.icns"
ENTITLEMENTS="Resources/Hexa.entitlements"
for artifact in "$BINARY" "$HELPER" "$DYLIB" "$RESOURCES_BUNDLE" "$ICNS" "$ENTITLEMENTS" "LICENSE"; do
  if [ ! -e "$artifact" ]; then
    echo "erro: artefato de build ausente: $artifact" >&2
    exit 1
  fi
done

# Carimbo do AppInfo: sha curto, com -dirty quando houver mudança não
# commitada (inclusive WIP do operador), como o próprio AppInfo documenta.
SHORT_SHA="$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain)" ]; then
  SHORT_SHA="$SHORT_SHA-dirty"
fi
BUILD_COMMIT="$SHORT_SHA · $(date '+%Y-%m-%d %H:%M')"
RELEASE_VERSION="$(python3 scripts/release/release_version.py)"
BUNDLE_VERSION="${RELEASE_VERSION%%-*}"
# Identifica o helper efetivamente compilado, inclusive duas trees dirty distintas.
HELPER_VERSION="$(shasum -a 256 "$HELPER" | awk '{print $1}')"
SIGN_IDENTITY="${HEXA_CODESIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
  # Prefere o certificado do mantenedor; o Team ID é público, não é credencial.
  SIGNING_TEAM_ID="${HEXA_CODESIGN_TEAM_ID:-3BM68QCBGK}"
  SIGNING_IDENTITIES=($(security find-identity -v -p codesigning \
    | awk -v team="($SIGNING_TEAM_ID)" '/^[[:space:]]*[0-9]+\)/ && index($0, team) {print $2}'))
  if [ "${#SIGNING_IDENTITIES[@]}" -eq 1 ]; then
    SIGN_IDENTITY="${SIGNING_IDENTITIES[0]}"
  else
    SIGNING_IDENTITIES=($(security find-identity -v -p codesigning \
      | awk '/^[[:space:]]*[0-9]+\)/ {print $2}'))
  fi
  if [ -z "$SIGN_IDENTITY" ] && [ "${#SIGNING_IDENTITIES[@]}" -eq 1 ]; then
    SIGN_IDENTITY="${SIGNING_IDENTITIES[0]}"
  elif [ -z "$SIGN_IDENTITY" ]; then
    echo "erro: não foi possível escolher uma identidade de assinatura; defina HEXA_CODESIGN_IDENTITY (assinatura ad-hoc não autentica o FanControl)" >&2
    exit 1
  fi
fi

echo "==> montando $APP (Config=$CONFIG, commit=$SHORT_SHA)"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Frameworks" "$CONTENTS/Resources" "$CONTENTS/Library/LaunchDaemons"
cp "$BINARY" "$CONTENTS/MacOS/Hexa"
cp "$HELPER" "$CONTENTS/MacOS/FanControlHelper"
cp "$DYLIB" "$CONTENTS/Frameworks/"
cp -R "$RESOURCES_BUNDLE" "$CONTENTS/Resources/"
cp "$ICNS" "$CONTENTS/Resources/AppIcon.icns"
# Texto da GPL-3.0 junto do programa distribuído (DEC-028).
cp "LICENSE" "$CONTENTS/Resources/LICENSE"
# Notas da versão exibidas na tela Sobre.
cp "CHANGELOG.md" "$CONTENTS/Resources/CHANGELOG.md"
if [ -d "Sources/Hexa/Resources/Fonts" ]; then
  cp -R "Sources/Hexa/Resources/Fonts" "$CONTENTS/Resources/"
fi
if [ -f "Resources/now-playing.pl" ]; then
  cp "Resources/now-playing.pl" "$CONTENTS/Resources/now-playing.pl"
fi

# Strings de permissão do Info.plist localizadas nos 15 idiomas (DEC-016);
# o macOS resolve o .lproj pela língua do sistema ao mostrar o prompt.
INFOPLIST_DIR="Resources/InfoPlist"
if [ -d "$INFOPLIST_DIR" ]; then
  for lproj in "$INFOPLIST_DIR"/*.lproj; do
    mkdir -p "$CONTENTS/Resources/$(basename "$lproj")"
    cp "$lproj/InfoPlist.strings" "$CONTENTS/Resources/$(basename "$lproj")/"
  done
fi

# O executável do SwiftPM carrega rpaths absolutos da máquina de build
# (PackageFrameworks); a distribuição local aponta para o próprio bundle.
RPATH="@executable_path/../Frameworks"
if ! otool -l "$CONTENTS/MacOS/Hexa" | grep -q "$RPATH"; then
  install_name_tool -add_rpath "$RPATH" "$CONTENTS/MacOS/Hexa"
fi
STALE_RPATH="$(otool -l "$CONTENTS/MacOS/Hexa" | awk '/cmd LC_RPATH/{getline; while ($0 !~ /path /) getline; print $2}' | grep '/PackageFrameworks' | head -1 || true)"
if [ -n "$STALE_RPATH" ]; then
  install_name_tool -delete_rpath "$STALE_RPATH" "$CONTENTS/MacOS/Hexa"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Hexa</string>
    <key>CFBundleDisplayName</key><string>Hexa</string>
    <key>CFBundleExecutable</key><string>Hexa</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$BUNDLE_VERSION</string>
    <key>HexaReleaseVersion</key><string>$RELEASE_VERSION</string>
    <key>CFBundleVersion</key><string>$(date '+%Y%m%d%H%M%S')</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleDevelopmentRegion</key><string>en-US</string>
    <key>ATSApplicationFontsPath</key><string>Fonts</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSUIElement</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key><string>Hexa uses Bluetooth to read the battery level of your connected accessories in Monitor > Power and in the Dynamic Island, only after you ask for it.</string>
    <key>NSAudioCaptureUsageDescription</key><string>Hexa captures audio from the current player for the Dynamic Island equalizer and from apps you select for mixing.</string>
    <key>NSCalendarsFullAccessUsageDescription</key><string>Hexa reads your calendar events to show your agenda and countdowns in the Dynamic Island.</string>
    <key>NSAppleEventsUsageDescription</key><string>Hexa sends commands to other apps only when you use a feature that needs it: the current music player for playback controls, Finder to move protected items to the Trash, and Terminal to run Homebrew commands that ask for your password.</string>
    <key>NSMicrophoneUsageDescription</key><string>Hexa never records from the microphone. macOS may ask for this access when the Mixer or the Dynamic Island equalizer reads the sound of other apps.</string>
    <key>NSScreenCaptureUsageDescription</key><string>Hexa captures screen content and window titles for screenshot and OCR tools, only after you ask for it.</string>
    <key>NSDesktopFolderUsageDescription</key><string>Hexa accesses your Desktop folder to scan for caches and leftover files from the Cleaner and Uninstaller, only after you ask for it.</string>
    <key>NSDocumentsFolderUsageDescription</key><string>Hexa accesses your Documents folder to scan for caches and leftover files from the Cleaner and Uninstaller, only after you ask for it.</string>
    <key>NSDownloadsFolderUsageDescription</key><string>Hexa accesses your Downloads folder to scan for caches and leftover files from the Cleaner and Uninstaller, only after you ask for it.</string>
    <key>HexaBuildCommit</key><string>$BUILD_COMMIT</string>
    <key>HexaFanControlHelperVersion</key><string>$HELPER_VERSION</string>
</dict>
</plist>
PLIST

# Serviço Mach ativa o helper sob demanda; sem RunAtLoad.
cat > "$CONTENTS/Library/LaunchDaemons/$HELPER_ID.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$HELPER_ID</string>
    <key>BundleProgram</key><string>Contents/MacOS/FanControlHelper</string>
    <key>MachServices</key>
    <dict><key>$HELPER_ID</key><true/></dict>
    <key>KeepAlive</key>
    <dict>
        <key>PathState</key>
        <dict><key>/var/run/hexa-fan-control.active</key><true/></dict>
    </dict>
</dict>
</plist>
PLIST

echo "==> codesign local autenticado"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$CONTENTS/Frameworks/libNowPlayingAdapter.dylib"
codesign --force --options runtime --sign "$SIGN_IDENTITY" --identifier "$HELPER_ID" "$CONTENTS/MacOS/FanControlHelper"
codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$CONTENTS/MacOS/Hexa"
codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
TEAM_ID="$(codesign -dv "$APP" 2>&1 | awk -F= '/^TeamIdentifier=/ {print $2}')"
if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "not set" ]; then
  echo "erro: a assinatura precisa de Team ID para autenticar o FanControl" >&2
  exit 1
fi
codesign --verify --test-requirement="=anchor apple generic and certificate leaf[subject.OU] = \"$TEAM_ID\" and identifier \"$BUNDLE_ID\"" "$APP"
codesign --verify --test-requirement="=anchor apple generic and certificate leaf[subject.OU] = \"$TEAM_ID\" and identifier \"$HELPER_ID\"" "$CONTENTS/MacOS/FanControlHelper"

echo "==> pronto: $APP"

if [ "$PROBE" = true ]; then
  "$CONTENTS/MacOS/Hexa" --settings-presentation-test
  "$CONTENTS/MacOS/Hexa" --notch-presentation-test
  "$CONTENTS/MacOS/Hexa" --notch-presentation-test --quick-access-clicks
  "$CONTENTS/MacOS/Hexa" --notch-presentation-test --media-layout
fi
