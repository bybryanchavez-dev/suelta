#!/bin/bash
# Compila Suelta.app.
#   bash build.sh          compila e instala en Aplicaciones
#   bash build.sh --pkg    compila y crea el instalador build/Suelta-Instalador.pkg
# Necesita las Command Line Tools de Xcode: xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"
MODE="${1:-install}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
APP="build/Suelta.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ARCH=$(uname -m)
echo "Compilando Suelta $VERSION para ${ARCH}..."
xcrun swiftc -O -parse-as-library -swift-version 5 \
  -target "${ARCH}-apple-macos26.0" \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/Suelta"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/*.wav "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/es.lproj" "$APP/Contents/Resources/en.lproj"
iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

if [ "$MODE" = "--pkg" ]; then
  echo "Creando el instalador..."
  mkdir -p build/pkgroot/Applications build/pkgs
  cp -R "$APP" build/pkgroot/Applications/
  pkgbuild --analyze --root build/pkgroot build/component.plist >/dev/null
  /usr/libexec/PlistBuddy -c "Delete :0:BundleIsRelocatable" build/component.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" build/component.plist
  pkgbuild --quiet --root build/pkgroot --component-plist build/component.plist \
    --identifier com.bryanchavez.suelta.app --version "$VERSION" --install-location / build/pkgs/SueltaApp.pkg
  pkgbuild --quiet --nopayload --scripts installer/scripts-es \
    --identifier com.bryanchavez.suelta.lang.es --version "$VERSION" build/pkgs/LangES.pkg
  pkgbuild --quiet --nopayload --scripts installer/scripts-en \
    --identifier com.bryanchavez.suelta.lang.en --version "$VERSION" build/pkgs/LangEN.pkg
  productbuild --quiet --distribution installer/distribution.xml --resources installer/resources \
    --package-path build/pkgs "build/Suelta-Instalador.pkg"
  echo "Instalador listo: build/Suelta-Instalador.pkg"
  exit 0
fi

DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x Suelta 2>/dev/null || true
rm -rf "$DEST/Suelta.app"
cp -R "$APP" "$DEST/"
echo "Instalada en $DEST/Suelta.app"
