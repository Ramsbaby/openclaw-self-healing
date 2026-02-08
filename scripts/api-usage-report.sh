#!/bin/bash

# API 사용량 통합 리포트
# OpenAI, Brave Search, Claude 사용량 정리

echo "📊 API 사용량 리포트"
echo "===================="
echo

# 1. Claude CLI 사용량 (claude /usage에서 가져온 데이터)
echo "## 🤖 Claude"
claude <<< "/usage" 2>/dev/null | grep -E "Current week|All models|Sonnet" | head -6
echo

# 2. OpenAI (수동 기록 - 대시보드에서 확인 필요)
echo "## 🟡 OpenAI API"
if [ -f ~/openclaw/memory/api-costs.json ]; then
  jq '.openai | "\(.used_dollars | "$" + tostring) used | \(.remaining_dollars | "$" + tostring) remaining"' ~/openclaw/memory/api-costs.json
else
  echo "⚠️ 데이터 없음 (platform.openai.com에서 수동 확인)"
fi
echo

# 3. Brave Search (수동 기록 - 대시보드에서 확인 필요)
echo "## 🔍 Brave Search API"
if [ -f ~/openclaw/memory/api-costs.json ]; then
  jq '.brave | "\(.used_queries | tostring) / \(.monthly_limit | tostring) queries | $\(.monthly_cost | tostring)"' ~/openclaw/memory/api-costs.json
else
  echo "⚠️ 데이터 없음 (api.search.brave.com 대시보드에서 수동 확인)"
fi
echo

# 4. 시스템 상태
echo "## ⚙️ OpenClaw 세션"
openclaw session_status 2>/dev/null | grep "Token\|Context\|Compaction"

