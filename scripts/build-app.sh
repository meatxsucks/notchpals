#!/bin/bash
# Empaqueta NotchPals como NotchPals.app (con los textos de permisos que macOS exige).
# Uso:  ./scripts/build-app.sh            → build nativo
#       UNIVERSAL=1 ./scripts/build-app.sh → Intel + Apple Silicon
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/NotchPals.app"
VERSION="${VERSION:-0.1.0}"

ARCHS=()
[ "${UNIVERSAL:-0}" = "1" ] && ARCHS=(--arch arm64 --arch x86_64)
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/NotchPals"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchPals"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NotchPals</string>
    <key>CFBundleDisplayName</key><string>NotchPals</string>
    <key>CFBundleIdentifier</key><string>com.notchpals.app</string>
    <key>CFBundleExecutable</key><string>NotchPals</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>NotchPals muestra tus próximos eventos en el notch.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>NotchPals muestra tus próximos eventos en el notch.</string>
    <key>NSAppTransportSecurity</key>
    <dict><key>NSAllowsLocalNetworking</key><true/></dict>
    <key>NSAppleEventsUsageDescription</key>
    <string>NotchPals controla Spotify y Apple Music para mostrar la pista y los controles.</string>
</dict>
</plist>
PLIST

# Firma ad-hoc: suficiente para correr en tu propio Mac.
codesign --force --deep --sign - "$APP"
echo "Listo: $APP"
echo "Ábrela con:  open $APP    (si macOS la bloquea: clic derecho → Abrir)"
