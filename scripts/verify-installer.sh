#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.5.0}"
REQUIRE_SIGNED_INSTALLER="${REQUIRE_SIGNED_INSTALLER:-0}"
FINAL_DIR="$ROOT_DIR/release/HSVoice-$VERSION"
FINAL_PKG="$FINAL_DIR/HSVoice-Installer-$VERSION.pkg"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
SOURCE_COMPONENT="$DIST_DIR/HSVoice-$VERSION-universal.pkg"
APP_PATH="$DIST_DIR/HS Voice.app"
WORK_DIR="$ROOT_DIR/.artifacts/installer-inspection"
EXPANDED_DIR="$WORK_DIR/product"
COMPONENT_DIR="$EXPANDED_DIR/HSVoice-component.pkg"

case "$WORK_DIR" in
    "$ROOT_DIR"/.artifacts/*) ;;
    *) echo "Refusing to use an unexpected inspection directory" >&2; exit 1 ;;
esac
case "$DIST_DIR" in
    "$ROOT_DIR/dist"|"$ROOT_DIR"/.artifacts/*) ;;
    *) echo "Refusing to inspect an unexpected release output directory" >&2; exit 1 ;;
esac

test -f "$FINAL_PKG"
test -f "$SOURCE_COMPONENT"
test -d "$APP_PATH"

FILE_COUNT="$(find "$FINAL_DIR" -mindepth 1 -maxdepth 1 -type f -print | wc -l | tr -d ' ')"
if [[ "$FILE_COUNT" != "1" ]]; then
    echo "Expected exactly one final installer file, found $FILE_COUNT" >&2
    exit 1
fi

SIGNATURE_OUTPUT="$(pkgutil --check-signature "$FINAL_PKG" 2>&1 || true)"
echo "$SIGNATURE_OUTPUT"
if [[ "$REQUIRE_SIGNED_INSTALLER" == "1" && "$SIGNATURE_OUTPUT" == *"Status: no signature"* ]]; then
    echo "The final installer is required to be signed" >&2
    exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
pkgutil --expand "$FINAL_PKG" "$EXPANDED_DIR"

test -f "$EXPANDED_DIR/Distribution"
test -f "$EXPANDED_DIR/Resources/welcome.html"
test -f "$EXPANDED_DIR/Resources/readme.html"
test -f "$EXPANDED_DIR/Resources/conclusion.html"
test -d "$COMPONENT_DIR"
xmllint --noout "$EXPANDED_DIR/Distribution"
test -f "$COMPONENT_DIR/PackageInfo"
test -f "$COMPONENT_DIR/Payload"
test -f "$COMPONENT_DIR/Bom"
grep -q 'install-location="/Applications"' "$COMPONENT_DIR/PackageInfo"
grep -q 'bundle path="./HS Voice.app"' "$COMPONENT_DIR/PackageInfo"
grep -q 'relocatable="false"' "$COMPONENT_DIR/PackageInfo"

lsbom -s "$COMPONENT_DIR/Bom" > "$WORK_DIR/payload-files.txt"
grep -q '^./HS Voice.app/Contents/Info.plist$' "$WORK_DIR/payload-files.txt"
grep -q '^./HS Voice.app/Contents/MacOS/HSVoice$' "$WORK_DIR/payload-files.txt"

plutil -lint "$APP_PATH/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/HSVoice")"
[[ "$ARCHITECTURES" == *"arm64"* ]]
[[ "$ARCHITECTURES" == *"x86_64"* ]]

installer -pkginfo -plist -pkg "$FINAL_PKG" > "$WORK_DIR/installer-package-info.plist"
plutil -lint "$WORK_DIR/installer-package-info.plist"

echo "Verified one Installer-compatible PKG, Japanese resources, /Applications payload, and Universal executable."
