#!/bin/bash
# HS Voice 1.5.0 (build 17): テスト → universalビルド → インストーラ作成
# 進行状況と結果は tmp/build17.log に記録される (Claude作成)
set -uo pipefail
cd "$(dirname "$0")"
LOG="tmp/build17.log"
rm -f tmp/build17.SUCCESS tmp/build17.FAILED
{
  echo "=== HS Voice 1.5.0 build 17: started $(date) ==="
  echo "--- swift test ---"
  if ! xcrun swift test 2>&1; then
    echo "=== TESTS FAILED ==="
    touch tmp/build17.FAILED
    exit 1
  fi
  echo "--- build installer ---"
  if ! ./scripts/build-installer.sh 2>&1; then
    echo "=== BUILD FAILED ==="
    touch tmp/build17.FAILED
    exit 1
  fi
  echo "=== SUCCESS $(date) ==="
  touch tmp/build17.SUCCESS
} 2>&1 | tee "$LOG"
if [ -f tmp/build17.SUCCESS ]; then
  killall HSVoice 2>/dev/null || true
  open "release/HSVoice-1.5.0/HSVoice-Installer-1.5.0.pkg"
fi
