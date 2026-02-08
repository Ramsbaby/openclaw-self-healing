#!/usr/bin/env bash
# ~/openclaw/scripts/channel-quality-rules-v2.sh
# Phase 2: Rule-based Quality Sampling (2시간 간격)
# LLM 없이 패턴 매칭으로 빠르고 토큰 0 소모

set -euo pipefail

DISCORD_TOKEN=$(jq -r '.channels.discord.token' ~/.openclaw/openclaw.json)

CHANNELS=(
  "1468386844621144065:#jarvis"
  "1469190686145384513:#jarvis-market"
  "1469190688083280065:#jarvis-system"
  "1469905074661757049:#jarvis-dev"
)

ALERT_CHANNEL="1469190688083280065"

# 중복 방지
STATE_FILE=~/openclaw/memory/quality-sampling-state.json

if [ ! -f "$STATE_FILE" ]; then
  echo '{}' > "$STATE_FILE"
fi

NOW=$(date +%s)

# 규칙 기반 체크 함수
check_jarvis() {
  local content="$1"
  local violations=()
  
  # ChatGPT 톤 감지
  if echo "$content" | grep -qiE "(알겠습니다!|완료!|기쁩니다|감사합니다!|도와드리겠습니다)"; then
    violations+=("ChatGPT 톤 감지")
  fi
  
  # 2000자 초과 (분할 실패)
  if [ ${#content} -gt 2000 ]; then
    violations+=("2000자 초과 (${#content}자)")
  fi
  
  echo "${violations[@]:-}"
}

check_market() {
  local content="$1"
  local violations=()
  
  # USD 가격 없음
  if ! echo "$content" | grep -qE '\$[0-9]+(\.[0-9]+)?'; then
    violations+=("USD 가격 누락")
  fi
  
  # KRW 환율 없음
  if ! echo "$content" | grep -qE '₩[0-9,]+'; then
    violations+=("KRW 환율 누락")
  fi
  
  # 변동률 없음
  if ! echo "$content" | grep -qE '[+-]?[0-9]+(\.[0-9]+)?%'; then
    violations+=("변동률(%) 누락")
  fi
  
  echo "${violations[@]:-}"
}

check_system() {
  local content="$1"
  local violations=()
  
  # 긴급도 이모지 없음
  if ! echo "$content" | grep -qE '(🚨|⚠️|ℹ️|✅)'; then
    violations+=("긴급도 이모지 누락")
  fi
  
  # 로그 10줄 초과 (줄바꿈 카운트)
  local line_count=$(echo "$content" | grep -c '^' || echo 0)
  if [ "$line_count" -gt 15 ]; then
    violations+=("로그 과다 (${line_count}줄)")
  fi
  
  echo "${violations[@]:-}"
}

check_dev() {
  local content="$1"
  local violations=()
  
  # ChatGPT 톤
  if echo "$content" | grep -qiE "(알겠습니다!|완료!|기쁩니다|처리 완료!.*🎉)"; then
    violations+=("ChatGPT 톤 감지")
  fi
  
  # 코드블록 언어 미명시 (```\n 패턴)
  if echo "$content" | grep -qE '```\n[^a-z]'; then
    violations+=("코드블록 언어 미명시")
  fi
  
  echo "${violations[@]:-}"
}

for ENTRY in "${CHANNELS[@]}"; do
  IFS=":" read -r CHANNEL_ID CHANNEL_NAME <<< "$ENTRY"
  
  echo "🔍 Sampling: $CHANNEL_NAME"
  
  # Discord API로 최근 10개 메시지 조회
  MESSAGES=$(curl -s -X GET \
    "https://discord.com/api/v10/channels/$CHANNEL_ID/messages?limit=10" \
    -H "Authorization: Bot $DISCORD_TOKEN")
  
  # 봇 메시지만 필터
  BOT_MSG=$(echo "$MESSAGES" | jq '[.[] | select(.author.bot == true)] | .[0]' 2>/dev/null || echo "{}")
  
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
  
  # 중복 체크 (1시간)
  LAST_EVAL=$(jq -r ".\"$MSG_ID\" // 0" "$STATE_FILE")
  if [ $((NOW - LAST_EVAL)) -lt 3600 ]; then
    echo "  ⏭️  최근 평가 완료 ($(((NOW - LAST_EVAL) / 60))분 전)"
    continue
  fi
  
  echo "  📊 규칙 기반 체크 중..."
  
  # 채널별 규칙 적용
  VIOLATIONS=""
  case "$CHANNEL_NAME" in
    "#jarvis")
      VIOLATIONS=$(check_jarvis "$MSG_CONTENT")
      ;;
    "#jarvis-market")
      VIOLATIONS=$(check_market "$MSG_CONTENT")
      ;;
    "#jarvis-system")
      VIOLATIONS=$(check_system "$MSG_CONTENT")
      ;;
    "#jarvis-dev")
      VIOLATIONS=$(check_dev "$MSG_CONTENT")
      ;;
  esac
  
  # 위반 없으면 양호
  if [ -z "$VIOLATIONS" ]; then
    echo "  ✅ 품질 양호 (규칙 위반 없음)"
  else
    echo "  ⚠️  품질 문제 발견!"
    
    # 알림 전송
    ALERT_MSG="⚠️ **품질 샘플링 경고 (규칙 기반)**

채널: $CHANNEL_NAME
시각: $(date '+%Y-%m-%d %H:%M KST')

**위반 항목:**
$(echo "$VIOLATIONS" | sed 's/ /, /g')

**메시지 ID:** \`${MSG_ID}\`
**길이:** ${MSG_LEN}자"
    
    curl -s -X POST \
      "https://discord.com/api/v10/channels/$ALERT_CHANNEL/messages" \
      -H "Authorization: Bot $DISCORD_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $(echo "$ALERT_MSG" | jq -Rs .)}" > /dev/null
  fi
  
  # 평가 기록
  jq ".\"$MSG_ID\" = $NOW" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  
done

echo ""
echo "✅ 샘플링 완료 (다음 실행: 2시간 후)"
