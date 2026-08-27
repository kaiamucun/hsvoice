#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.6.0}"
BUILD_NUMBER="${BUILD_NUMBER:-19}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.hsvoice.desktop}"
APP_SIGNING_IDENTITY="${APP_SIGNING_IDENTITY:--}"
INSTALLER_SIGNING_IDENTITY="${INSTALLER_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SKIP_DMG="${SKIP_DMG:-0}"

ARTIFACTS_DIR="$ROOT_DIR/.artifacts"
WORK_DIR="$ARTIFACTS_DIR/release-work"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_PATH="$DIST_DIR/HS Voice.app"
PKG_PATH="$DIST_DIR/HSVoice-$VERSION-universal.pkg"
DMG_PATH="$DIST_DIR/HSVoice-$VERSION-universal.dmg"
PACKAGE_ROOT="$WORK_DIR/package-root"
COMPONENT_PLIST="$ROOT_DIR/Packaging/HSVoiceComponent.plist"

case "$WORK_DIR" in
    "$ROOT_DIR"/.artifacts/*) ;;
    *) echo "Refusing to use an unexpected release work directory" >&2; exit 1 ;;
esac
case "$DIST_DIR" in
    "$ROOT_DIR/dist"|"$ROOT_DIR"/.artifacts/*) ;;
    *) echo "Refusing to use an unexpected release output directory" >&2; exit 1 ;;
esac

rm -rf "$WORK_DIR" "$APP_PATH"
rm -f "$PKG_PATH" "$DMG_PATH"
mkdir -p "$WORK_DIR" "$DIST_DIR" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

export CLANG_MODULE_CACHE_PATH="$ARTIFACTS_DIR/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ARTIFACTS_DIR/swiftpm-module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

build_architecture() {
    local architecture="$1"
    local triple="${architecture}-apple-macosx13.0"
    local scratch="$WORK_DIR/swift-$architecture"

    xcrun swift build \
        --package-path "$ROOT_DIR" \
        --disable-sandbox \
        --configuration release \
        --triple "$triple" \
        --scratch-path "$scratch"

    local binary
    binary="$(find "$scratch" -type f -path '*/release/HSVoice' -perm -111 -print -quit)"
    if [[ -z "$binary" ]]; then
        echo "Could not locate the $architecture release executable" >&2
        exit 1
    fi
    echo "$binary"
}

echo "Building HS Voice $VERSION for Apple Silicon..."
ARM64_BINARY="$(build_architecture arm64 | tail -n 1)"
echo "Building HS Voice $VERSION for Intel..."
X86_64_BINARY="$(build_architecture x86_64 | tail -n 1)"

lipo -create "$ARM64_BINARY" "$X86_64_BINARY" -output "$APP_PATH/Contents/MacOS/HSVoice"
chmod 755 "$APP_PATH/Contents/MacOS/HSVoice"

cp "$ROOT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"

"$ROOT_DIR/scripts/generate-icon.sh" "$APP_PATH/Contents/Resources/AppIcon.icns" >/dev/null

# Source files edited through a device bridge (e.g. Claude Cowork) can carry
# owner-only modes (600), ACLs, and stray extended attributes. pkgbuild records
# modes verbatim and the payload installs root-owned, so an unreadable
# Info.plist bricks the installed app ("executable is missing", version "--").
# Normalize the whole bundle before signing so the signature covers the final
# state and every payload file is world-readable.
chmod -RN "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true
find "$APP_PATH" -name '._*' -delete
chmod -R u+rwX,go+rX "$APP_PATH"

if [[ "$APP_SIGNING_IDENTITY" == "-" ]]; then
    echo "Applying an ad-hoc signature for local testing..."
    codesign --force --deep --sign - "$APP_PATH"
else
    echo "Signing app with Developer ID..."
    codesign --force --deep --options runtime --timestamp \
        --entitlements "$ROOT_DIR/Packaging/HSVoice.entitlements" \
        --sign "$APP_SIGNING_IDENTITY" "$APP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ "$APP_SIGNING_IDENTITY" == "-" ]]; then
        echo "NOTARY_PROFILE requires a Developer ID Application signature" >&2
        exit 1
    fi
    APP_ZIP="$WORK_DIR/HSVoice-notarization.zip"
    ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
    xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_PATH"
fi

mkdir -p "$PACKAGE_ROOT"
cp -R "$APP_PATH" "$PACKAGE_ROOT/HS Voice.app"

# Belt and braces: verify the payload carries no owner-only entries before it
# is sealed into the component package.
chmod -R u+rwX,go+rX "$PACKAGE_ROOT"
BAD_MODES="$(find "$PACKAGE_ROOT" \( -type f ! -perm -044 \) -o \( -type d ! -perm -055 \) | head -5)"
if [[ -n "$BAD_MODES" ]]; then
    echo "Refusing to package files that are not world-readable:" >&2
    echo "$BAD_MODES" >&2
    exit 1
fi

PKG_ARGUMENTS=(
    --root "$PACKAGE_ROOT"
    --component-plist "$COMPONENT_PLIST"
    --install-location /Applications
    --identifier "$BUNDLE_IDENTIFIER.pkg"
    --version "$VERSION"
)
if [[ -n "$INSTALLER_SIGNING_IDENTITY" ]]; then
    PKG_ARGUMENTS+=(--sign "$INSTALLER_SIGNING_IDENTITY")
fi
pkgbuild "${PKG_ARGUMENTS[@]}" "$PKG_PATH"

DMG_STAGE="$WORK_DIR/dmg"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/HS Voice.app"
ln -s /Applications "$DMG_STAGE/Applications"
if [[ "$SKIP_DMG" == "1" ]]; then
    if [[ -n "$NOTARY_PROFILE" ]]; then
        echo "SKIP_DMG cannot be used with NOTARY_PROFILE" >&2
        exit 1
    fi
    echo "Skipping DMG creation as requested; the prepared source is at $DMG_STAGE"
else
    hdiutil create -volname "HS Voice" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
fi

if [[ "$SKIP_DMG" != "1" && "$APP_SIGNING_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$APP_SIGNING_IDENTITY" "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ -z "$INSTALLER_SIGNING_IDENTITY" ]]; then
        echo "NOTARY_PROFILE requires INSTALLER_SIGNING_IDENTITY for the installer package" >&2
        exit 1
    fi
    xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PKG_PATH"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
fi

echo
echo "Release artifacts:"
echo "  $APP_PATH"
echo "  $PKG_PATH"
if [[ "$SKIP_DMG" != "1" ]]; then
    echo "  $DMG_PATH"
fi
