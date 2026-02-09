#!/bin/bash
# Real-time Quality Monitor V1.1
# Discord 응답 품질을 실시간 모니터링하고 낮은 품질 감지 시 #jarvis-system 알림
#
# 실행 빈도: 5분마다 (cron)
# 대상: 최근 Gateway 로그 (Discord 응답만)
# 알림 임계값: 간단한 휴리스틱으로 "나쁜 응답" 감지

set -euo pipefail

OPENCLAW_DIR=~/openclaw
LOG_DIR="$OPENCLAW_DIR/memory/quality-monitor"
ALERT_LOG="$LOG_DIR/alerts-$(date +%Y-%m-%d).log"
STATE_FILE="$LOG_DIR/state.json"
GATEWAY_LOG=~/.openclaw/logs/gateway.log

mkdir -p "$LOG_DIR"

# 상태 파일 로드 (마지막 체크 라인 번호)
LAST_LINE=$(jq -r '.last_line // 0' "$STATE_FILE" 2>/dev/null || echo "0")
CURRENT_LINE=$(wc -l < "$GATEWAY_LOG" | tr -d ' ')

# 새 라인이 없으면 종료
if [ "$CURRENT_LINE" -le "$LAST_LINE" ]; then
  echo "No new log lines. Exiting."
  exit 0
fi

# 새 라인만 추출
NEW_LINES=$(tail -n +$((LAST_LINE + 1)) "$GATEWAY_LOG")

# Discord 응답 필터링 및 품질 체크
VIOLATIONS=""

# 1. ChatGPT 톤 체크
if echo "$NEW_LINES" | grep -qi "알겠습니다!\|완료!\|기쁩니다"; then
  VIOLATIONS="${VIOLATIONS}• ChatGPT 톤 감지 (알겠습니다!/완료!/기쁩니다)\n"
fi

# 2. 빈 칭찬 체크
if echo "$NEW_LINES" | grep -qi "좋은 질문입니다\|훌륭한"; then
  VIOLATIONS="${VIOLATIONS}• 빈 칭찬 감지\n"
fi

# 3. Discord 포맷 위반 (빈 줄 누락)
if echo "$NEW_LINES" | grep -E "##[^#]" | grep -v $'\n\n##' > /dev/null 2>&1; then
  VIOLATIONS="${VIOLATIONS}• Discord 포맷 위반 (소제목 앞뒤 빈 줄 누락)\n"
fi

# 4. 추측 표현 체크
if echo "$NEW_LINES" | grep -qi "아마도\|~것 같습니다" | grep -v "확인" > /dev/null 2>&1; then
  VIOLATIONS="${VIOLATIONS}• 추측 표현 사용 (아마도/~것 같습니다)\n"
fi

# Discord 알림 (위반 감지 시)
if [ -n "$VIOLATIONS" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  
  MESSAGE="⚠️ **실시간 품질 알림**

시간: ${TIMESTAMP}
로그 라인: ${LAST_LINE} → ${CURRENT_LINE} (신규 $((CURRENT_LINE - LAST_LINE))줄)

**감지된 위반:**
${VIOLATIONS}

**다음 조치:**
1. 최근 Discord 응답 재검토
2. SOUL.md 및 AGENTS.md 준수 여부 확인
3. 필요 시 응답 수정 또는 재작성"

  openclaw message send \
    --channel discord \
    --target 1469190688083280065 \
    --message "$MESSAGE" 2>&1 | tee -a "$ALERT_LOG" || true
  
  echo "{\"last_line\": $CURRENT_LINE, \"last_alert\": \"$TIMESTAMP\"}" > "$STATE_FILE"
else
  echo "{\"last_line\": $CURRENT_LINE}" > "$STATE_FILE"
fi

echo "✅ Quality monitor run complete. New lines: $((CURRENT_LINE - LAST_LINE)), Violations: $(echo -n "$VIOLATIONS" | wc -l | tr -d ' ')"
