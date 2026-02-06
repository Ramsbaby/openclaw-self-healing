#!/bin/bash
# Market Macro Briefing (Layer 1: 거시 환경 분석)
# 실행: 매일 아침 06:15 (모닝 브리핑 통합)

set -euo pipefail

WEBHOOK_URL="https://discord.com/api/webhooks/1468751194284621967/2pYU-tCo4EcIXtB5XsOFfWvW0WLcSK7nnN-JcxRwWELQAFHuqkxWZ5-oWZxqHPWNzuSJ"
SKILL_DIR="$HOME/openclaw/skills/market-environment-analysis"

echo "🌍 Market Environment Analysis 실행 중..."

# Market Environment Analysis 실행
MARKET_ENV=$(cd "$SKILL_DIR" && uv run scripts/market_analysis.py 2>&1 || echo "⚠️ Market Environment 분석 실패")

# 월요일만 Bubble Detector 실행
DAY_OF_WEEK=$(date +%u)  # 1=Mon, 7=Sun
BUBBLE_REPORT=""

if [ "$DAY_OF_WEEK" -eq 1 ]; then
    echo "🔍 Bubble Detector 실행 중 (월요일)..."
    BUBBLE_SKILL_DIR="$HOME/openclaw/skills/us-market-bubble-detector"
    BUBBLE_REPORT=$(cd "$BUBBLE_SKILL_DIR" && uv run scripts/detect_bubble.py 2>&1 || echo "⚠️ Bubble 분석 실패")
fi

# Discord 메시지 생성
MESSAGE=$(cat <<EOF
## 🌍 오늘의 시장 환경 ($(date '+%Y-%m-%d %a'))

$MARKET_ENV

$(if [ -n "$BUBBLE_REPORT" ]; then echo "---\n\n## 🔍 주간 버블 리스크 체크\n\n$BUBBLE_REPORT"; fi)

---
*Layer 1 (Macro): Market Environment + Bubble Risk*
EOF
)

# Discord 전송
curl -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg content "$MESSAGE" '{content: $content}')" \
    2>&1 || echo "⚠️ Discord 전송 실패"

echo "✅ Market Macro Briefing 완료"
