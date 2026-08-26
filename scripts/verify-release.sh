#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.5.0}"
APP_PATH="$ROOT_DIR/dist/HS Voice.app"
PKG_PATH="$ROOT_DIR/dist/HSVoice-$VERSION-universal.pkg"
DMG_PATH="$ROOT_DIR/dist/HSVoice-$VERSION-universal.dmg"

test -d "$APP_PATH"
test -f "$PKG_PATH"
test -f "$DMG_PATH"

plutil -lint "$APP_PATH/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/HSVoice")"
[[ "$ARCHITECTURES" == *"arm64"* ]]
[[ "$ARCHITECTURES" == *"x86_64"* ]]

pkgutil --check-signature "$PKG_PATH" || true
pkgutil --expand "$PKG_PATH" "$ROOT_DIR/.artifacts/pkg-inspection"
test -f "$ROOT_DIR/.artifacts/pkg-inspection/PackageInfo"
rm -rf "$ROOT_DIR/.artifacts/pkg-inspection"

hdiutil verify "$DMG_PATH"

echo "Verified app, universal executable, installer package, and disk image."
