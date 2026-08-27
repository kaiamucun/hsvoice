#!/bin/bash
# Windows版CIワークフロー修正をpushし、ビルドを再起動する (Claude作成)
# ダブルクリックで実行。結果は tmp/push-windows-ci.log に記録。
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p tmp
TAG=win-v1.0.1
{
  echo "=== push windows ci started $(date) ==="
  if [ -f .git/index.lock ] && ! pgrep -x git >/dev/null; then
    rm -f .git/index.lock && echo "stale index.lock removed"
  fi
  git add windows .github/workflows/windows-installer.yml windows-release.conf &&
  { git diff --cached --quiet && echo "変更なし" || git commit -m "Fix WIX0267: nest Files under Feature in Package.wxs"; } &&
  git push origin main &&
  git push --delete origin "$TAG" 2>/dev/null; git tag -d "$TAG" 2>/dev/null
  git tag "$TAG" &&
  git push origin "$TAG"
  if [ $? -eq 0 ]; then
    echo "=== SUCCESS: ビルドが起動しました ==="
    echo "進行状況: https://github.com/kaiamucun/hsvoice/actions"
  else
    echo "=== FAILED ==="
  fi
} 2>&1 | tee tmp/push-windows-ci.log
sleep 3
