#!/bin/bash
# git push origin main を実行し、結果を tmp/push.log に記録する (Claude作成)
set -uo pipefail
cd "$(dirname "$0")"
rm -f tmp/push.SUCCESS tmp/push.FAILED
{
  echo "=== git push started $(date) ==="
  if git push origin main 2>&1; then
    echo "=== PUSH SUCCESS $(date) ==="
    touch tmp/push.SUCCESS
  else
    echo "=== PUSH FAILED ==="
    touch tmp/push.FAILED
  fi
} 2>&1 | tee tmp/push.log
sleep 2
