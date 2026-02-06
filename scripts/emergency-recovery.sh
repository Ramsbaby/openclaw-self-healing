#!/bin/bash
set -euo pipefail

# OpenClaw Emergency Recovery (Level 3 Self-Healing)
# Claude Code PTY 세션으로 자동 진단 및 복구 시도

# ============================================
# Configuration (Override via environment)
# ============================================
RECOVERY_TIMEOUT="${EMERGENCY_RECOVERY_TIMEOUT:-1800}"  # 30분
GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789/}"
LOG_DIR="${OPENCLAW_MEMORY_DIR:-$HOME/openclaw/memory}"
CLAUDE_WORKSPACE_TRUST_TIMEOUT="${CLAUDE_WORKSPACE_TRUST_TIMEOUT:-10}"
CLAUDE_STARTUP_WAIT="${CLAUDE_STARTUP_WAIT:-5}"
WORKSPACE_TRUST_CONFIRM_WAIT="${WORKSPACE_TRUST_CONFIRM_WAIT:-3}"

TIMESTAMP=$(date +%Y-%m-%d-%H%M)
LOG_FILE="$LOG_DIR/emergency-recovery-$TIMESTAMP.log"
REPORT_FILE="$LOG_DIR/emergency-recovery-report-$TIMESTAMP.md"
SESSION_LOG="$LOG_DIR/claude-session-$TIMESTAMP.log"
TMUX_SESSION="emergency_recovery_$TIMESTAMP"

# Performance metrics
METRICS_FILE="$LOG_DIR/.emergency-recovery-metrics.json"

# Create log directory if not exists
mkdir -p "$LOG_DIR"

# Load environment variables
if [ -f "$HOME/openclaw/.env" ]; then
  # shellcheck source=/dev/null
  source "$HOME/openclaw/.env"
elif [ -f "$HOME/.openclaw/.env" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.openclaw/.env"
fi

# Discord webhook from environment variable (optional)
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"

if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "INFO: DISCORD_WEBHOOK_URL not set. Notifications disabled."
fi

# ============================================
# Functions
# ============================================

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_discord_notification() {
  local message="$1"
  if [ -n "$DISCORD_WEBHOOK" ]; then
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$message\"}" \
      2>&1 || echo "000")
    
    if [ "$response_code" = "200" ] || [ "$response_code" = "204" ]; then
      log "✅ Discord notification sent (HTTP $response_code)"
    else
      log "⚠️ Discord notification failed (HTTP $response_code)"
    fi
  fi
}

check_dependencies() {
  local missing_deps=()
  
  if ! command -v tmux &> /dev/null; then
    missing_deps+=("tmux")
  fi
  
  if ! command -v claude &> /dev/null; then
    missing_deps+=("claude")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    log "❌ Missing dependencies: ${missing_deps[*]}"
    send_discord_notification "🚨 **Level 3 Emergency Recovery 실패**\n\n필수 의존성이 설치되지 않았습니다:\n- ${missing_deps[*]}\n\n설치 방법:\n\`\`\`bash\nbrew install ${missing_deps[*]}\n\`\`\`"
    return 1
  fi
  
  log "✅ Dependencies check passed"
  return 0
}

wait_for_claude_prompt() {
  local session="$1"
  local timeout="$2"
  
  log "Waiting for Claude workspace trust prompt (timeout: ${timeout}s)..."
  
  for _ in $(seq 1 "$timeout"); do
    local output
    output=$(tmux capture-pane -t "$session" -p 2>/dev/null || echo "")
    
    if echo "$output" | grep -q "trust this workspace"; then
      log "✅ Claude workspace trust prompt detected"
      return 0
    fi
    
    sleep 1
  done
  
  log "⚠️ Claude workspace trust prompt not detected after ${timeout}s"
  return 1
}

capture_tmux_session() {
  local session="$1"
  local output_file="$2"
  
  if tmux capture-pane -t "$session" -p > "$output_file" 2>/dev/null; then
    log "✅ tmux session captured: $output_file"
    return 0
  else
    log "⚠️ Failed to capture tmux session"
    return 1
  fi
}

check_claude_quota() {
  local session_log="$1"
  
  if grep -qE "rate limit|quota exceeded|429|too many requests" "$session_log"; then
    log "⚠️ Claude API rate limited or quota exceeded"
    return 1
  fi
  
  return 0
}

rotate_old_logs() {
  local deleted_count
  deleted_count=$(find "$LOG_DIR" -name "emergency-recovery-*.log" -mtime +14 -delete -print 2>/dev/null | wc -l)
  deleted_count=$((deleted_count + $(find "$LOG_DIR" -name "claude-session-*.log" -mtime +14 -delete -print 2>/dev/null | wc -l)))
  
  if [ "$deleted_count" -gt 0 ]; then
    log "Rotated $deleted_count old log files"
  fi
}

record_metric() {
  local metric_name="$1"
  local result="$2"
  local duration="$3"
  local timestamp
  timestamp=$(date +%s)
  
  # Append to metrics file (JSON Lines format)
  echo "{\"timestamp\":$timestamp,\"metric\":\"$metric_name\",\"result\":\"$result\",\"duration\":$duration}" >> "$METRICS_FILE"
}

cleanup_tmux_session() {
  local session="$1"
  
  if tmux has-session -t "$session" 2>/dev/null; then
    log "Terminating tmux session: $session"
    tmux kill-session -t "$session" 2>/dev/null || true
  fi
}

# ============================================
# Main Recovery Logic
# ============================================

main() {
  local start_time
  start_time=$(date +%s)
  
  log "=== Emergency Recovery Started (PID: $$) ==="
  
  # 0. Log rotation
  rotate_old_logs
  
  # 1. Check dependencies
  if ! check_dependencies; then
    log "🚨 Cannot proceed without required dependencies"
    record_metric "emergency_recovery" "dependency_failed" 0
    exit 1
  fi
  
  # 2. Claude Code PTY 세션 시작
  log "Starting Claude Code session in tmux..."
  
  if ! tmux new-session -d -s "$TMUX_SESSION" "claude" 2>> "$LOG_FILE"; then
    log "❌ Failed to start tmux session"
    send_discord_notification "🚨 **Level 3 실패**\n\ntmux 세션 시작 실패.\n\n수동 개입 필요:\n\`$LOG_FILE\`"
    record_metric "emergency_recovery" "tmux_failed" 0
    exit 1
  fi
  
  sleep "$CLAUDE_STARTUP_WAIT"
  
  # 3. 워크스페이스 신뢰 (프롬프트 감지)
  if wait_for_claude_prompt "$TMUX_SESSION" "$CLAUDE_WORKSPACE_TRUST_TIMEOUT"; then
    log "Trusting workspace..."
    tmux send-keys -t "$TMUX_SESSION" "" C-m
    sleep "$WORKSPACE_TRUST_CONFIRM_WAIT"
  else
    log "⚠️ Proceeding without workspace trust confirmation"
  fi
  
  # 4. 긴급 복구 명령 전송
  log "Sending emergency recovery command to Claude..."
  
  local recovery_command
  recovery_command="OpenClaw 게이트웨이가 5분간 재시작했으나 복구되지 않았습니다. 긴급 진단 및 복구를 시작하세요.

작업 순서:
1. \`openclaw status\` 체크
2. 로그 분석 (~/.openclaw/logs/*.log)
3. 설정 검증 (~/.openclaw/openclaw.json)
4. 포트 충돌 체크 (\`lsof -i :18789\`)
5. 의존성 체크 (\`npm list\`, \`node --version\`)
6. 복구 시도 (설정 수정, 프로세스 재시작)
7. 결과를 $REPORT_FILE 에 기록

작업 제한시간: ${RECOVERY_TIMEOUT}초 이내
목표: Gateway가 $GATEWAY_URL 에서 HTTP 200 응답하도록 복구"
  
  if ! tmux send-keys -t "$TMUX_SESSION" "$recovery_command" C-m 2>> "$LOG_FILE"; then
    log "❌ Failed to send command to Claude"
    cleanup_tmux_session "$TMUX_SESSION"
    send_discord_notification "🚨 **Level 3 실패**\n\nClaude 명령 전송 실패.\n\n수동 개입 필요:\n\`$LOG_FILE\`"
    record_metric "emergency_recovery" "command_failed" 0
    exit 1
  fi
  
  # 5. Claude 작업 대기
  log "Waiting ${RECOVERY_TIMEOUT}s for Claude to complete recovery..."
  sleep "$RECOVERY_TIMEOUT"
  
  # 6. tmux 세션 캡처
  log "Capturing Claude session output..."
  capture_tmux_session "$TMUX_SESSION" "$SESSION_LOG"
  
  # 7. Claude 할당량 체크
  local SUCCESS="unknown"
  
  if ! check_claude_quota "$SESSION_LOG"; then
    send_discord_notification "⚠️ **Level 3 Emergency Recovery 실패**\n\nClaude API 할당량 소진 또는 속도 제한.\n\n다음 단계:\n1. Claude 할당량 확인: \`claude\` → \`/usage\`\n2. 수동 복구 시도\n\n세션 로그: \`$SESSION_LOG\`"
    SUCCESS="false"
  fi
  
  # 8. 결과 확인
  log "Checking recovery result..."
  
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$GATEWAY_URL" 2>/dev/null || echo "000")
  
  if [ "$http_code" = "200" ] && [ "$SUCCESS" != "false" ]; then
    log "✅ Claude successfully recovered the gateway! (HTTP $http_code)"
    SUCCESS="true"
  else
    log "❌ Gateway still unhealthy after Claude recovery (HTTP $http_code)"
    SUCCESS="false"
  fi
  
  # 9. tmux 세션 종료
  cleanup_tmux_session "$TMUX_SESSION"
  
  # 10. Performance metrics
  local end_time
  end_time=$(date +%s)
  local total_time=$((end_time - start_time))
  record_metric "emergency_recovery" "$SUCCESS" "$total_time"
  
  # 11. Discord 알림 및 종료
  log "=== Emergency Recovery Completed (${total_time}s) ==="
  
  if [ "$SUCCESS" = "true" ]; then
    log "✅ Sending success notification to Discord..."
    send_discord_notification "✅ **Level 3 Emergency Recovery 성공!**\n\nGateway가 Claude에 의해 복구되었습니다.\n- 복구 시간: ${total_time}초\n- HTTP 상태: $http_code\n- 로그: \`$LOG_FILE\`\n- Claude 세션: \`$SESSION_LOG\`"
    exit 0
  else
    log "🚨 Sending failure notification to Discord..."

    local failure_msg
    failure_msg="🚨 **Level 3 Emergency Recovery 실패!**\n\n**모든 자동 복구 시스템이 실패했습니다:**\n- Level 1 (Watchdog): ❌\n- Level 2 (Health Check): ❌\n- Level 3 (Claude Recovery): ❌\n\n**수동 개입 필요**\n- HTTP 상태: $http_code\n- 복구 시간: ${total_time}초\n- 로그: \`$LOG_FILE\`\n- Claude 세션: \`$SESSION_LOG\`\n- 복구 리포트: \`$REPORT_FILE\` (Claude가 생성했을 경우)"

    send_discord_notification "$failure_msg"

    # 로그에도 기록
    cat >> "$LOG_FILE" << EOF

=== MANUAL INTERVENTION REQUIRED ===
Level 1 (Watchdog) ❌
Level 2 (Health Check) ❌
Level 3 (Claude Recovery) ❌

수동 개입 필요합니다.
복구 시간: ${total_time}초
로그: $LOG_FILE
Claude 세션: $SESSION_LOG
복구 리포트: $REPORT_FILE (Claude가 생성했을 경우)
EOF

    exit 1
  fi
}

# Run main function
main

# ============================================
# v1.1.0: Incident Documentation (ContextVault feedback)
# ============================================
log_incident() {
    local incident_file="${OPENCLAW_DIR}/memory/incidents/$(date +%Y-%m-%d_%H%M%S).md"
    mkdir -p "$(dirname "$incident_file")"
    
    cat > "$incident_file" << EOF
# Incident Report - $(date '+%Y-%m-%d %H:%M:%S')

## Trigger
- Health check failed 3 times
- Last error: $(tail -5 "${OPENCLAW_DIR}/logs/gateway.log" 2>/dev/null | head -3)

## Claude Diagnosis
$(tmux capture-pane -t emergency-recovery -p 2>/dev/null | tail -50)

## Resolution
- Status: $1
- Duration: $2 seconds

## Prevention
- TODO: Add prevention steps based on root cause
EOF
    
    echo "📝 Incident logged: $incident_file"
}
