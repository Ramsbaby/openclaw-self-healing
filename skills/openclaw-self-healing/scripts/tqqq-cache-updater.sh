#!/bin/bash
# TQQQ 캐시 업데이터
# 5분 크론에서 실행 → 최신 데이터를 파일에 저장

set -euo pipefail

CACHE_FILE="$HOME/openclaw/memory/tqqq-cache.json"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Yahoo Finance 스크립트 실행
TQQQ_DATA=$(python3 ~/openclaw/scripts/tqqq-yahoo-monitor.py 2>/dev/null)

# JSON 형식으로 저장
cat > "$CACHE_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "data": $(echo "$TQQQ_DATA" | jq -Rs '.')
}
EOF

chmod 600 "$CACHE_FILE"
echo "✅ TQQQ 캐시 업데이트 완료: $TIMESTAMP"
