#!/usr/bin/env bash
# ~/openclaw/scripts/channel-quality-sampling.sh
# Phase 2: Sampling Validation Cron (2시간 간격)
# 각 채널 최근 1개 메시지만 13-criteria 평가

set -euo pipefail

GUILD_ID="483238980280647680"
CHANNELS=(
  "1468386844621144065:#jarvis"
  "1469190686145384513:#jarvis-market"
  "1469190688083280065:#jarvis-system"
  "1469905074661757049:#jarvis-dev"
)

ALERT_CHANNEL="1469190688083280065"
THRESHOLD=6.0

# 중복 방지 (1시간 이내 동일 채널 알림 억제)
STATE_FILE=~/openclaw/memory/quality-sampling-state.json

# 초기화
if [ ! -f "$STATE_FILE" ]; then
  echo '{}' > "$STATE_FILE"
fi

NOW=$(date +%s)

for ENTRY in "${CHANNELS[@]}"; do
  IFS=":" read -r CHANNEL_ID CHANNEL_NAME <<< "$ENTRY"
  
  echo "🔍 Sampling: $CHANNEL_NAME"
  
  # 최근 10개 메시지 조회 (봇 메시지 찾기)
  MESSAGES=$(openclaw message action:search \
    guildId:"$GUILD_ID" \
    channelId:"$CHANNEL_ID" \
    limit:10 2>/dev/null || echo "[]")
  
  # 봇 본인 메시지만 필터링 (author.bot = true)
  MESSAGES=$(echo "$MESSAGES" | jq '[.[] | select(.author.bot == true)] | .[0:1]')
  
  # 메시지 없으면 스킵
  if [ "$(echo "$MESSAGES" | jq '. | length')" -eq 0 ]; then
    echo "  ⏭️  메시지 없음"
    continue
  fi
  
  MSG_CONTENT=$(echo "$MESSAGES" | jq -r '.[0].content // ""')
  MSG_ID=$(echo "$MESSAGES" | jq -r '.[0].id // ""')
  MSG_TIMESTAMP=$(echo "$MESSAGES" | jq -r '.[0].timestamp // ""')
  
  # 500자 미만 스킵
  MSG_LEN=${#MSG_CONTENT}
  if [ "$MSG_LEN" -lt 500 ]; then
    echo "  ⏭️  메시지 너무 짧음 ($MSG_LEN자)"
    continue
  fi
  
  # 중복 체크 (1시간 내 동일 메시지 평가 방지)
  LAST_EVAL=$(jq -r ".\"$MSG_ID\" // 0" "$STATE_FILE")
  if [ $((NOW - LAST_EVAL)) -lt 3600 ]; then
    echo "  ⏭️  최근 평가 완료 ($(((NOW - LAST_EVAL) / 60))분 전)"
    continue
  fi
  
  echo "  📊 13-criteria 평가 중..."
  
  # LLM 평가 (Claude Haiku로 토큰 절약)
  EVAL_RESULT=$(cat <<EOF | openclaw --model haiku --quiet 2>/dev/null || echo "error"
다음 Discord 메시지를 13가지 기준으로 평가하세요.

**채널:** $CHANNEL_NAME
**메시지 길이:** $MSG_LEN자
**타임스탬프:** $MSG_TIMESTAMP

**메시지 내용:**
\`\`\`
$MSG_CONTENT
\`\`\`

**13-Criteria 평가 (각 1점, 총 13점):**
1. Clarity (명확성)
2. Specificity (구체성)
3. Consistency (일관성)
4. Role Separation (채널 역할 준수)
5. Output Contract (필수 항목 포함)
6. Failure Handling (에러 처리)
7. Context Switching (불필요한 주제 전환 없음)
8. Measurability (측정 가능성)
9. Security (민감 정보 마스킹)
10. UX (사용자 경험)
11. Scalability (확장성)
12. Differentiation (채널 차별화)
13. Productivity (생산성)

JSON 형식으로만 출력:
{
  "score": X.X,
  "passed": [기준1, 기준2, ...],
  "failed": [기준3, 기준4, ...],
  "summary": "한 줄 요약"
}
EOF
)
  
  # JSON 파싱
  SCORE=$(echo "$EVAL_RESULT" | jq -r '.score // 0' 2>/dev/null || echo "0")
  FAILED=$(echo "$EVAL_RESULT" | jq -r '.failed // [] | join(", ")' 2>/dev/null || echo "")
  SUMMARY=$(echo "$EVAL_RESULT" | jq -r '.summary // "평가 실패"' 2>/dev/null || echo "평가 실패")
  
  echo "  점수: $SCORE/13"
  
  # 임계값 미달 시 알림
  if (( $(echo "$SCORE < $THRESHOLD" | bc -l) )); then
    echo "  ⚠️  품질 임계값 미달!"
    
    openclaw message action:send target:"$ALERT_CHANNEL" message:"⚠️ 품질 샘플링 경고

채널: $CHANNEL_NAME
점수: $SCORE/13 (임계값: $THRESHOLD)
시각: $(date '+%Y-%m-%d %H:%M KST')

**실패 항목:**
$FAILED

**요약:**
$SUMMARY

**메시지 ID:** $MSG_ID
**길이:** $MSG_LEN자" 2>/dev/null || true
  else
    echo "  ✅ 품질 양호"
  fi
  
  # 평가 기록
  jq ".\"$MSG_ID\" = $NOW" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  
done

echo ""
echo "✅ 샘플링 완료 (다음 실행: 2시간 후)"
