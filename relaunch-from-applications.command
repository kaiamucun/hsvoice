#!/bin/bash
# 旧HSVoiceプロセスを終了し、/Applications の新版を起動 (Claude作成)
set -uo pipefail
cd "$(dirname "$0")"
killall HSVoice 2>/dev/null
sleep 1
mkdir -p tmp/old-app-copies
mv "dist/HS Voice.app" "tmp/old-app-copies/dist_HS Voice.app" 2>/dev/null && echo "旧distコピーを退避しました"
open "/Applications/HS Voice.app"
echo "=== /Applications の HS Voice (1.4.0 build 12) を起動しました ==="
