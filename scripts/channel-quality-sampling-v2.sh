#!/usr/bin/env bash
# ~/openclaw/scripts/channel-quality-sampling-v2.sh
# Phase 2: Sampling Validation Cron (2시간 간격)
# Discord REST API 직접 호출

set -euo pipefail

# Discord Bot Token 가져오기
DISCORD_TOKEN=$(jq -r '.channels.discord.token' ~/.openclaw/openclaw.json)

CHANNELS=(
  "1468386844621144065:#jarvis"
  "1469190686145384513:#jarvis-market"
  "1469190688083280065:#jarvis-system"
  "1469905074661757049:#jarvis-dev"
)

ALERT_CHANNEL="1469190688083280065"
THRESHOLD=6.0

# 중복 방지
STATE_FILE=~/openclaw/memory/quality-sampling-state.json

if [ ! -f "$STATE_FILE" ]; then
  echo '{}' > "$STATE_FILE"
fi

NOW=$(date +%s)

for ENTRY in "${CHANNELS[@]}"; do
  IFS=":" read -r CHANNEL_ID CHANNEL_NAME <<< "$ENTRY"
  
  echo "🔍 Sampling: $CHANNEL_NAME"
  
  # Discord REST API: GET /channels/{channel.id}/messages
  MESSAGES=$(curl -s -X GET \
    "https://discord.com/api/v10/channels/$CHANNEL_ID/messages?limit=10" \
    -H "Authorization: Bot $DISCORD_TOKEN" \
    -H "Content-Type: application/json")
  
  # 봇 메시지만 필터 (author.bot = true)
  BOT_MSG=$(echo "$MESSAGES" | jq '[.[] | select(.author.bot == true)] | .[0]' 2>/dev/null || echo "{}")
  
  # 메시지 없으면 스킵
  if [ "$(echo "$BOT_MSG" | jq -r '.id // ""')" == "" ]; then
    echo "  ⏭️  봇 메시지 없음"
    continue
  fi
  
  MSG_CONTENT=$(echo "$BOT_MSG" | jq -r '.content // ""')
  MSG_ID=$(echo "$BOT_MSG" | jq -r '.id // ""')
  MSG_TIMESTAMP=$(echo "$BOT_MSG" | jq -r '.timestamp // ""')
  
  # 500자 미만 스킵
  MSG_LEN=${#MSG_CONTENT}
  if [ "$MSG_LEN" -lt 500 ]; then
    echo "  ⏭️  메시지 너무 짧음 ($MSG_LEN자)"
    continue
  fi
  
  # 중복 체크
  LAST_EVAL=$(jq -r ".\"$MSG_ID\" // 0" "$STATE_FILE")
  if [ $((NOW - LAST_EVAL)) -lt 3600 ]; then
    echo "  ⏭️  최근 평가 완료 ($(((NOW - LAST_EVAL) / 60))분 전)"
    continue
  fi
  
  echo "  📊 13-criteria 평가 중... (메시지 ID: ${MSG_ID:0:10}...)"
  
  # Claude Haiku로 평가 (OpenClaw CLI 사용)
  EVAL_PROMPT="다음 Discord 메시지를 13가지 기준으로 평가하세요.

**채널:** $CHANNEL_NAME
**메시지 길이:** $MSG_LEN자

**메시지 내용:**
\`\`\`
${MSG_CONTENT:0:1500}
\`\`\`

**13-Criteria (각 1점, 총 13점):**
1. Clarity 2. Specificity 3. Consistency 4. Role Separation
5. Output Contract 6. Failure Handling 7. Context Switching
8. Measurability 9. Security 10. UX 11. Scalability
12. Differentiation 13. Productivity

JSON만:
{\"score\": X.X, \"passed\": [\"A\"], \"failed\": [\"B\"], \"summary\": \"요약\"}"
  
  # OpenClaw CLI로 평가
  EVAL_RESULT=$(echo "$EVAL_PROMPT" | openclaw --model haiku --quiet 2>/dev/null | grep -o '{.*}' | head -1 || echo '{"score": 0, "passed": [], "failed": [], "summary": "평가 실패"}')
  
  # JSON 파싱
  SCORE=$(echo "$EVAL_RESULT" | jq -r '.score // 0' 2>/dev/null || echo "0")
  FAILED=$(echo "$EVAL_RESULT" | jq -r '.failed // [] | join(", ")' 2>/dev/null || echo "")
  SUMMARY=$(echo "$EVAL_RESULT" | jq -r '.summary // "평가 실패"' 2>/dev/null || echo "평가 실패")
  
  echo "  점수: $SCORE/13"
  
  # 임계값 미달 시 알림 (Discord API로 직접 전송)
  if (( $(echo "$SCORE < $THRESHOLD" | bc -l) )); then
    echo "  ⚠️  품질 임계값 미달!"
    
    ALERT_MSG="⚠️ **품질 샘플링 경고**

채널: $CHANNEL_NAME
점수: $SCORE/13 (임계값: $THRESHOLD)
시각: $(date '+%Y-%m-%d %H:%M KST')

**실패 항목:**
$FAILED

**요약:**
$SUMMARY

**메시지 ID:** \`${MSG_ID}\`
**길이:** ${MSG_LEN}자"
    
    curl -s -X POST \
      "https://discord.com/api/v10/channels/$ALERT_CHANNEL/messages" \
      -H "Authorization: Bot $DISCORD_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $(echo "$ALERT_MSG" | jq -Rs .)}" > /dev/null
  else
    echo "  ✅ 품질 양호"
  fi
  
  # 평가 기록
  jq ".\"$MSG_ID\" = $NOW" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  
done

echo ""
echo "✅ 샘플링 완료 (다음 실행: 2시간 후)"
