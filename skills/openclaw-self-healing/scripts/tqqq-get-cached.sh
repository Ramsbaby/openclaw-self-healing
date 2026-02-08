#!/bin/bash
# TQQQ 캐시 조회 (즉시 응답)

set -euo pipefail

CACHE_FILE="$HOME/openclaw/memory/tqqq-cache.json"

if [[ ! -f "$CACHE_FILE" ]]; then
  echo "❌ 캐시 파일 없음. 실시간 조회 중..."
  python3 ~/openclaw/scripts/tqqq-yahoo-monitor.py
  exit 0
fi

# 캐시 나이 체크 (5분 = 300초)
AGE=$(( $(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE") ))
if (( AGE > 300 )); then
  echo "⚠️ 캐시 만료 (${AGE}초). 실시간 조회 중..."
  python3 ~/openclaw/scripts/tqqq-yahoo-monitor.py
  exit 0
fi

# 캐시 데이터 출력
jq -r '.data' "$CACHE_FILE"
echo ""
echo "📌 캐시 조회 (${AGE}초 전 데이터)"
