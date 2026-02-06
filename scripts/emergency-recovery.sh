#!/bin/bash

# OpenClaw Emergency Recovery (Level 3 Self-Healing)
# Claude Code PTY 세션으로 자동 진단 및 복구 시도

TIMESTAMP=$(date +%Y-%m-%d-%H%M)
LOG_FILE=~/openclaw/memory/emergency-recovery-$TIMESTAMP.log
REPORT_FILE=~/openclaw/memory/emergency-recovery-report-$TIMESTAMP.md
TMUX_SESSION="emergency_recovery_$TIMESTAMP"
RECOVERY_TIMEOUT=1800  # 30분
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1468429341154214049/arTEGUkhIZ5bpE63AefMnyneomjwf1zDzCpzCwbdlzKpH7KgNzcMpFNX9G-DPW5HRojU"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

{
  log "=== Emergency Recovery Started ==="
  
  # 1. Claude Code PTY 세션 시작
  log "Starting Claude Code session..."
  tmux new-session -d -s "$TMUX_SESSION" "claude"
  sleep 5
  
  # 2. 워크스페이스 신뢰 (Enter 자동 입력)
  log "Trusting workspace..."
  tmux send-keys -t "$TMUX_SESSION" "" C-m
  sleep 3
  
  # 3. 긴급 복구 명령 전송
  log "Sending emergency recovery command to Claude..."
  
  RECOVERY_COMMAND="OpenClaw 게이트웨이가 5분간 재시작했으나 복구되지 않았습니다. 긴급 진단 및 복구를 시작하세요.

작업 순서:
1. \`openclaw status\` 체크
2. 로그 분석 (~/.openclaw/logs/*.log)
3. 설정 검증 (~/.openclaw/openclaw.json)
4. 포트 충돌 체크 (\`lsof -i :18789\`)
5. 의존성 체크 (\`npm list\`, \`node --version\`)
6. 복구 시도 (설정 수정, 프로세스 재시작)
7. 결과를 $REPORT_FILE 에 기록

작업 제한시간: 30분 이내
목표: Gateway가 http://localhost:18789/ 에서 HTTP 200 응답하도록 복구"
  
  tmux send-keys -t "$TMUX_SESSION" "$RECOVERY_COMMAND" C-m
  
  # 4. 30분 대기 (Claude 작업 시간)
  log "Waiting ${RECOVERY_TIMEOUT}s for Claude to complete recovery..."
  sleep "$RECOVERY_TIMEOUT"
  
  # 5. 결과 확인
  log "Checking recovery result..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/ 2>/dev/null)
  
  if [ "$HTTP_CODE" = "200" ]; then
    log "✅ Claude successfully recovered the gateway! (HTTP $HTTP_CODE)"
    SUCCESS=true
  else
    log "❌ Gateway still unhealthy after Claude recovery (HTTP $HTTP_CODE)"
    SUCCESS=false
  fi
  
  # 6. tmux 세션 캡처 및 종료
  log "Capturing Claude session output..."
  tmux capture-pane -t "$TMUX_SESSION" -p > ~/openclaw/memory/claude-session-$TIMESTAMP.log 2>/dev/null
  
  log "Terminating Claude session..."
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
  
  # 7. Discord 알림
  if [ "$SUCCESS" = true ]; then
    log "✅ Sending success notification to Discord..."
    curl -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"✅ **Level 3 Emergency Recovery 성공!**\n\nGateway가 Claude에 의해 복구되었습니다.\n- 복구 시간: $TIMESTAMP\n- HTTP 상태: $HTTP_CODE\n- 로그: \`$LOG_FILE\`\"}" \
      2>/dev/null
  else
    log "🚨 Sending failure notification to Discord..."

    FAILURE_MSG="🚨 **Level 3 Emergency Recovery 실패!**\n\n**모든 자동 복구 시스템이 실패했습니다:**\n- Level 1 (Auto-Retry): ❌\n- Level 2 (Health Check): ❌\n- Level 3 (Claude Recovery): ❌\n\n**수동 개입 필요**\n- HTTP 상태: $HTTP_CODE\n- 로그: \`$LOG_FILE\`\n- Claude 세션: \`~/openclaw/memory/claude-session-$TIMESTAMP.log\`\n- 복구 리포트: \`$REPORT_FILE\` (생성된 경우)"

    curl -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$FAILURE_MSG\"}" \
      2>/dev/null

    # 로그에도 기록
    cat >> "$LOG_FILE" << EOF

=== MANUAL INTERVENTION REQUIRED ===
Level 1 (Auto-Retry) ❌
Level 2 (Health Check) ❌
Level 3 (Claude Recovery) ❌

수동 개입 필요합니다.
로그: $LOG_FILE
Claude 세션: ~/openclaw/memory/claude-session-$TIMESTAMP.log
복구 리포트: $REPORT_FILE (Claude가 생성했을 경우)
EOF
  fi
  
  log "=== Emergency Recovery Completed ==="
  
} >> "$LOG_FILE" 2>&1

# 종료 코드 반환
if [ "$SUCCESS" = true ]; then
  exit 0
else
  exit 1
fi
