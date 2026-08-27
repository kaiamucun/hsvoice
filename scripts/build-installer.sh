#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.6.0}"
BUILD_NUMBER="${BUILD_NUMBER:-19}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.hsvoice.desktop}"
APP_SIGNING_IDENTITY="${APP_SIGNING_IDENTITY:--}"
INSTALLER_SIGNING_IDENTITY="${INSTALLER_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

ARTIFACTS_DIR="$ROOT_DIR/.artifacts"
WORK_DIR="$ARTIFACTS_DIR/installer-work"
FINAL_DIR="$ROOT_DIR/release/HSVoice-$VERSION"
FINAL_PKG="$FINAL_DIR/HSVoice-Installer-$VERSION.pkg"
BUILD_OUTPUT_DIR="$WORK_DIR/release-output"
COMPONENT_SOURCE="$BUILD_OUTPUT_DIR/HSVoice-$VERSION-universal.pkg"
COMPONENT_NAME="HSVoice-component.pkg"
COMPONENT_PATH="$WORK_DIR/$COMPONENT_NAME"
DISTRIBUTION_TEMPLATE="$ROOT_DIR/Packaging/Installer/Distribution.xml.in"
DISTRIBUTION_PATH="$WORK_DIR/Distribution.xml"
RESOURCES_DIR="$ROOT_DIR/Packaging/Installer/Resources"
PACKAGE_IDENTIFIER="$BUNDLE_IDENTIFIER.pkg"

case "$WORK_DIR" in
    "$ROOT_DIR"/.artifacts/*) ;;
    *) echo "Refusing to use an unexpected installer work directory" >&2; exit 1 ;;
esac
case "$FINAL_DIR" in
    "$ROOT_DIR"/release/HSVoice-*) ;;
    *) echo "Refusing to use an unexpected final installer directory" >&2; exit 1 ;;
esac
case "$VERSION" in
    ""|*[!0-9A-Za-z._-]*) echo "VERSION contains unsupported characters" >&2; exit 1 ;;
esac
case "$BUNDLE_IDENTIFIER" in
    ""|*[!0-9A-Za-z._-]*) echo "BUNDLE_IDENTIFIER contains unsupported characters" >&2; exit 1 ;;
esac

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ "$APP_SIGNING_IDENTITY" == "-" || -z "$INSTALLER_SIGNING_IDENTITY" ]]; then
        echo "NOTARY_PROFILE requires both Developer ID Application and Installer identities" >&2
        exit 1
    fi
fi

rm -rf "$WORK_DIR" "$FINAL_DIR"
mkdir -p "$WORK_DIR" "$FINAL_DIR"

echo "Building the Universal HS Voice application and component package..."
VERSION="$VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
APP_SIGNING_IDENTITY="$APP_SIGNING_IDENTITY" \
INSTALLER_SIGNING_IDENTITY="$INSTALLER_SIGNING_IDENTITY" \
NOTARY_PROFILE="" \
SKIP_DMG=1 \
DIST_DIR="$BUILD_OUTPUT_DIR" \
    "$ROOT_DIR/scripts/build-release.sh"

test -f "$COMPONENT_SOURCE"
cp "$COMPONENT_SOURCE" "$COMPONENT_PATH"

sed \
    -e "s/@BUNDLE_IDENTIFIER@/$BUNDLE_IDENTIFIER/g" \
    -e "s/@PACKAGE_IDENTIFIER@/$PACKAGE_IDENTIFIER/g" \
    -e "s/@VERSION@/$VERSION/g" \
    "$DISTRIBUTION_TEMPLATE" > "$DISTRIBUTION_PATH"

PRODUCTBUILD_ARGUMENTS=(
    --distribution "$DISTRIBUTION_PATH"
    --resources "$RESOURCES_DIR"
    --package-path "$WORK_DIR"
)
if [[ -n "$INSTALLER_SIGNING_IDENTITY" ]]; then
    PRODUCTBUILD_ARGUMENTS+=(--sign "$INSTALLER_SIGNING_IDENTITY")
fi

echo "Creating one double-clickable installer package..."
productbuild "${PRODUCTBUILD_ARGUMENTS[@]}" "$FINAL_PKG"

if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$FINAL_PKG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$FINAL_PKG"
    xcrun stapler validate "$FINAL_PKG"
fi

REQUIRE_SIGNED_INSTALLER=0
if [[ -n "$INSTALLER_SIGNING_IDENTITY" ]]; then
    REQUIRE_SIGNED_INSTALLER=1
fi

VERSION="$VERSION" \
REQUIRE_SIGNED_INSTALLER="$REQUIRE_SIGNED_INSTALLER" \
DIST_DIR="$BUILD_OUTPUT_DIR" \
    "$ROOT_DIR/scripts/verify-installer.sh"

echo
echo "Single-file installer ready:"
echo "  $FINAL_PKG"
