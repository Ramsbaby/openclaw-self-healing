#!/bin/bash
# Claude 사용량 간단 확인 (stats-cache.json 기반)

CACHE=~/.claude/stats-cache.json

if [ ! -f "$CACHE" ]; then
    echo "❌ stats-cache.json not found"
    exit 1
fi

echo "📊 Claude 사용량 (로컬 캐시 기반)"
echo ""

# 최근 7일 토큰 합산
jq -r '.dailyModelTokens[-7:] | map(.tokensByModel | to_entries | map(.value)) | flatten | add' "$CACHE" 2>/dev/null || echo "0"

echo ""
echo "💡 정확한 한도는 웹에서 확인:"
echo "   https://claude.ai/settings/usage"
