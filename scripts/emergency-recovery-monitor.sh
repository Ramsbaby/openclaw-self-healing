#!/bin/bash

# Emergency Recovery Monitor - Discord 알림
# emergency-recovery 로그에서 실패 케이스 감지 → Discord 알림

LOG_DIR=~/openclaw/memory
ALERT_SENT_FILE=~/openclaw/memory/.emergency-alert-sent

# 최근 30분 내 emergency-recovery 로그 찾기
RECENT_LOGS=$(find "$LOG_DIR" -name "emergency-recovery-*.log" -mmin -30 2>/dev/null)

if [ -z "$RECENT_LOGS" ]; then
  # 최근 emergency recovery 없음
  exit 0
fi

# 가장 최근 로그 확인
LATEST_LOG=$(ls -t "$LOG_DIR"/emergency-recovery-*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
  exit 0
fi

# 이미 알림 보낸 로그인지 체크
if [ -f "$ALERT_SENT_FILE" ]; then
  SENT_LOG=$(cat "$ALERT_SENT_FILE")
  if [ "$SENT_LOG" = "$LATEST_LOG" ]; then
    # 이미 알림 보냄
    exit 0
  fi
fi

# "MANUAL INTERVENTION REQUIRED" 패턴 검색
if grep -q "MANUAL INTERVENTION REQUIRED" "$LATEST_LOG"; then
  TIMESTAMP=$(basename "$LATEST_LOG" | sed 's/emergency-recovery-//;s/.log//')
  
  # Discord 알림 (OpenClaw message tool은 크론에서 직접 사용 불가, systemEvent로 전달)
  cat > /tmp/emergency-alert.txt << EOF
🚨 **긴급: OpenClaw 자가복구 실패**

**시간:** $TIMESTAMP
**상태:**
- Level 1 (Watchdog) ❌
- Level 2 (Health Check) ❌  
- Level 3 (Claude Recovery) ❌

**수동 개입 필요합니다.**

**로그:**
- \`$LATEST_LOG\`
- \`~/openclaw/memory/claude-session-$TIMESTAMP.log\`
- \`~/openclaw/memory/emergency-recovery-report-$TIMESTAMP.md\` (Claude 생성)

**복구 시도:**
1. \`openclaw status\` 확인
2. \`~/.openclaw/logs/*.log\` 에러 확인
3. \`openclaw gateway restart\` 시도
EOF

  # OpenClaw cron으로 알림 전송 (isolated session에서 실행)
  echo "Emergency recovery failed, sending alert to Discord #jarvis-health"
  
  # 알림 보냄 기록
  echo "$LATEST_LOG" > "$ALERT_SENT_FILE"
  
  # 리턴 1 = 크론이 실패로 인식 → Discord 알림 트리거
  exit 1
fi

exit 0
