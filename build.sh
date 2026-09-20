#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
SOURCE_VERSION="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
VERSION="${1:-$SOURCE_VERSION}"
BUNDLE_ID="com.justcallmebryan.gigi"

CORE=(Sources/Core/*.swift)
SWIFT_FLAGS=(-O -swift-version 5 -framework CoreGraphics -framework IOKit -framework ApplicationServices)

if [ ! -f Resources/GiGi.icns ]; then
  echo "==> icon"
  swift tools/make-icon.swift > /dev/null
fi

echo "==> CLI"
mkdir -p bin
swiftc "${SWIFT_FLAGS[@]}" "${CORE[@]}" Sources/cli/main.swift -o bin/gigi

echo "==> menu bar app"
APP="app/GiGi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/es.lproj"
swiftc "${SWIFT_FLAGS[@]}" -framework AppKit -framework ServiceManagement \
  "${CORE[@]}" Sources/app/*.swift -o "$APP/Contents/MacOS/GiGi"

cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
cp Resources/GiGi.icns "$APP/Contents/Resources/GiGi.icns"
for lang in en es; do
  cp "Resources/$lang.lproj/Localizable.strings" "$APP/Contents/Resources/$lang.lproj/Localizable.strings"
done
plutil -lint "$APP/Contents/Info.plist" > /dev/null
printf 'APPL????' > "$APP/Contents/PkgInfo"

IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -1 || true)}"
if [ -n "$IDENTITY" ]; then
  echo "==> signing with: $IDENTITY"
  codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP" >/dev/null 2>&1 \
    || { echo "    (signing failed, falling back to ad-hoc)"; codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" >/dev/null; }
else
  echo "==> no signing identity found: ad-hoc (macOS may ask for Accessibility again after a rebuild)"
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" >/dev/null 2>&1 || true
fi

echo
echo "OK"
echo "  version: $VERSION"
echo "  CLI: $(pwd)/bin/gigi"
echo "  app: $(pwd)/$APP"
echo
echo "try:"
echo "  ./bin/gigi probe --test"
echo "  open $APP && ./bin/gigi status"
echo "icons:"
echo "  swift tools/make-icon.swift --preview   # rebuilds Resources/GiGi.icns plus a HTML preview"
