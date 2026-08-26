#!/bin/bash
# ダウンロードサイト(docs/)を最新pkgで更新してGitHubへpushする (Claude作成)
# ダブルクリックで実行。結果は tmp/publish-site.log に記録。
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p tmp
rm -f tmp/publish-site.SUCCESS tmp/publish-site.FAILED
{
  echo "=== publish download site started $(date) ==="
  # 古いgitロックが残っていれば除去(他のgitプロセスが動いていない前提)
  if [ -f .git/index.lock ] && ! pgrep -x git >/dev/null; then
    rm -f .git/index.lock && echo "stale index.lock removed"
  fi
  ./scripts/update-download-site.sh &&
  git add docs/index.html docs/icon.svg docs/.nojekyll docs/downloads/HSVoice-Installer.pkg scripts/update-download-site.sh publish-download-site.command &&
  { git diff --cached --quiet && echo "変更なし(コミット不要)" || git commit -m "Add/update internal download site (docs/)"; } &&
  git push origin main
  if [ $? -eq 0 ]; then
    echo "=== PUBLISH SUCCESS $(date) ==="
    touch tmp/publish-site.SUCCESS
  else
    echo "=== PUBLISH FAILED ==="
    touch tmp/publish-site.FAILED
  fi
} 2>&1 | tee tmp/publish-site.log
sleep 2
