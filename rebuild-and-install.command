#!/bin/bash
# HS Voice: リビルドしてインストーラを開くスクリプト (Claude作成)
# 1) universal ビルド + pkg 作成  2) 旧アプリ終了  3) インストーラを開く
set -euo pipefail
cd "$(dirname "$0")"
./scripts/build-installer.sh
killall HSVoice 2>/dev/null || true
VERSION=$(grep -o "VERSION:-[0-9.]*" scripts/build-installer.sh | head -1 | cut -d- -f2)
open "release/HSVoice-$VERSION/HSVoice-Installer-$VERSION.pkg"
echo
echo "=== ビルド完了。インストーラが開きました ==="
