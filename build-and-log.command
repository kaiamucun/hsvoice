#!/bin/bash
# HS Voice 1.8.0 (build 25): テスト → universalビルド → インストーラ作成 → docs/downloads更新
# 進行状況と結果は tmp/build25.log に記録される (Claude作成)
set -uo pipefail
cd "$(dirname "$0")"
LOG="tmp/build25.log"
mkdir -p tmp
rm -f tmp/build25.SUCCESS tmp/build25.FAILED
{
  echo "=== HS Voice 1.8.0 build 25: started $(date) ==="
  echo "--- swift test ---"
  if ! xcrun swift test 2>&1; then
    echo "=== TESTS FAILED ==="
    touch tmp/build25.FAILED
    exit 1
  fi
  echo "--- build installer ---"
  if ! ./scripts/build-installer.sh 2>&1; then
    echo "=== BUILD FAILED ==="
    touch tmp/build25.FAILED
    exit 1
  fi
  echo "--- update download site (docs/) ---"
  if ! ./scripts/update-download-site.sh 2>&1; then
    echo "=== SITE UPDATE FAILED ==="
    touch tmp/build25.FAILED
    exit 1
  fi
  echo "=== SUCCESS $(date) ==="
  touch tmp/build25.SUCCESS
} 2>&1 | tee "$LOG"
if [ -f tmp/build25.SUCCESS ]; then
  killall HSVoice 2>/dev/null || true
  open "release/HSVoice-1.8.0/HSVoice-Installer-1.8.0.pkg"
fi
