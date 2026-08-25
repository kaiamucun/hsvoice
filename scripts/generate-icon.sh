#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_ICNS="${1:-$ROOT_DIR/.artifacts/AppIcon.icns}"
WORK_DIR="$ROOT_DIR/.artifacts/icon-work"
APPICONSET_DIR="$WORK_DIR/AppAssets.xcassets/AppIcon.appiconset"
COMPILED_DIR="$WORK_DIR/compiled"
BASE_PNG="$WORK_DIR/AppIcon-1024.png"

case "$WORK_DIR" in
    "$ROOT_DIR"/.artifacts/*) ;;
    *) echo "Refusing to use an unexpected icon work directory" >&2; exit 1 ;;
esac

rm -rf "$WORK_DIR"
mkdir -p "$APPICONSET_DIR" "$COMPILED_DIR" "$(dirname "$OUTPUT_ICNS")"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.artifacts/clang-module-cache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$ROOT_DIR/.artifacts/swift-script-module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"
xcrun swift -module-cache-path "$SWIFT_MODULECACHE_PATH" "$ROOT_DIR/scripts/generate-icon.swift" "$BASE_PNG"

make_icon() {
    local pixels="$1"
    local name="$2"
    sips -z "$pixels" "$pixels" "$BASE_PNG" --out "$APPICONSET_DIR/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

cp "$ROOT_DIR/Assets/AppIconContents.json" "$APPICONSET_DIR/Contents.json"
xcrun actool "$WORK_DIR/AppAssets.xcassets" \
    --compile "$COMPILED_DIR" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$WORK_DIR/asset-info.plist" \
    >/dev/null

if [[ ! -f "$COMPILED_DIR/AppIcon.icns" ]]; then
    echo "Asset compiler did not produce AppIcon.icns" >&2
    exit 1
fi
cp "$COMPILED_DIR/AppIcon.icns" "$OUTPUT_ICNS"
echo "$OUTPUT_ICNS"
