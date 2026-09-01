#!/bin/bash
# HS Voice 1.6.1 (build 20): テスト → universalビルド → インストーラ作成 → docs/downloads更新
# 進行状況と結果は tmp/build20.log に記録される (Claude作成)
set -uo pipefail
cd "$(dirname "$0")"
LOG="tmp/build20.log"
mkdir -p tmp
rm -f tmp/build20.SUCCESS tmp/build20.FAILED
{
  echo "=== HS Voice 1.6.1 build 20: started $(date) ==="
  echo "--- swift test ---"
  if ! xcrun swift test 2>&1; then
    echo "=== TESTS FAILED ==="
    touch tmp/build20.FAILED
    exit 1
  fi
  echo "--- build installer ---"
  if ! ./scripts/build-installer.sh 2>&1; then
    echo "=== BUILD FAILED ==="
    touch tmp/build20.FAILED
    exit 1
  fi
  echo "--- update download site (docs/) ---"
  if ! ./scripts/update-download-site.sh 2>&1; then
    echo "=== SITE UPDATE FAILED ==="
    touch tmp/build20.FAILED
    exit 1
  fi
  echo "=== SUCCESS $(date) ==="
  touch tmp/build20.SUCCESS
} 2>&1 | tee "$LOG"
if [ -f tmp/build20.SUCCESS ]; then
  killall HSVoice 2>/dev/null || true
  open "release/HSVoice-1.6.1/HSVoice-Installer-1.6.1.pkg"
fi
