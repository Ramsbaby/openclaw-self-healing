#!/bin/bash
set -euo pipefail

# OpenClaw Emergency Recovery (Level 3 Self-Healing)
# Claude Code PTY 세션으로 자동 진단 및 복구 시도

# ============================================
# Cleanup trap (ensure tmux session is killed on exit)
# ============================================
# shellcheck disable=SC2329,SC2317
cleanup() {
    local exit_code=$?
    if [ -n "${TMUX_SESSION:-}" ]; then
        tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    fi
    # Remove lock file if exists (uses $LOCKFILE set later, fallback to default)
    rm -rf "${LOCKDIR:-$HOME/openclaw/memory/.emergency-recovery.lock}" 2>/dev/null || true
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

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

# Create log directory FIRST (before any file operations)
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR" 2>/dev/null || true

# Secure session log (after directory exists)
touch "$SESSION_LOG"
chmod 600 "$SESSION_LOG"

# Secure lock location (atomic mkdir)
LOCKDIR="$LOG_DIR/.emergency-recovery.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Another emergency recovery is already running, skipping..."
  exit 0
fi

# Performance metrics
METRICS_FILE="$LOG_DIR/.emergency-recovery-metrics.json"

# Load environment variables
if [ -f "$HOME/openclaw/.env" ]; then
  # shellcheck source=/dev/null
  source "$HOME/openclaw/.env"
elif [ -f "$HOME/.openclaw/.env" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.openclaw/.env"
fi

# ============================================
# Load notification library
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/notify.sh
source "$SCRIPT_DIR/lib/notify.sh"

# ============================================
# Functions
# ============================================

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
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
    local install_hint="brew install"
    if [[ "$(uname -s)" == "Linux" ]]; then
      install_hint="apt/dnf/pacman install"
    fi
    send_notification "🚨 **Level 3 Emergency Recovery 실패**\n\n필수 의존성이 설치되지 않았습니다:\n- ${missing_deps[*]}\n\n설치 방법:\n\`\`\`bash\n$install_hint ${missing_deps[*]}\n\`\`\`"
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
    send_notification "🚨 **Level 3 실패**\n\ntmux 세션 시작 실패.\n\n수동 개입 필요:\n\`$LOG_FILE\`"
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

# MANDATORY FIRST STEPS (Read tool 호출 필수 — 진단 전 반드시 수행)
- 진단·복구 시도 전에 다음 중 **최소 2개**를 Read tool로 직접 읽어라.
- Read tool 호출 없이 진단할 경우 할루시네이션 위험 — 실제 시스템 상태를 모르면서 추측 처방하게 된다.
- 본 단계 누락 시 결과는 신뢰할 수 없으며 $REPORT_FILE 에 'tool_use=0 (할루시네이션 의심)'으로 기록하라.

  1. README.md  (전체 self-healing 4-tier chain — Level 1~3 흐름)
  2. ~/.openclaw/openclaw.json  (현재 게이트웨이 설정)
  3. ~/.openclaw/logs/*.log 최신 라인  (실제 에러 메시지)
  4. ./scripts/gateway-watchdog.sh 또는 ./scripts/gateway-healthcheck.sh  (Level 1~2 동작)

작업 순서 (위 MANDATORY 완료 후):
1. \`openclaw status\` 체크
2. 로그 분석 (~/.openclaw/logs/*.log)
3. 설정 검증 (~/.openclaw/openclaw.json)
4. 포트 충돌 체크 (\`lsof -i :18789\`)
5. 의존성 체크 (\`npm list\`, \`node --version\`)
6. 복구 시도 (설정 수정, 프로세스 재시작)
7. 결과를 $REPORT_FILE 에 기록 (Read tool 호출 횟수도 함께 기록)

작업 제한시간: ${RECOVERY_TIMEOUT}초 이내
목표: Gateway가 $GATEWAY_URL 에서 HTTP 200 응답하도록 복구"
  
  if ! tmux send-keys -t "$TMUX_SESSION" "$recovery_command" C-m 2>> "$LOG_FILE"; then
    log "❌ Failed to send command to Claude"
    cleanup_tmux_session "$TMUX_SESSION"
    send_notification "🚨 **Level 3 실패**\n\nClaude 명령 전송 실패.\n\n수동 개입 필요:\n\`$LOG_FILE\`"
    record_metric "emergency_recovery" "command_failed" 0
    exit 1
  fi
  
  # 5. Claude 작업 대기 (폴링으로 조기 완료 감지)
  log "Waiting for Claude to complete recovery (max ${RECOVERY_TIMEOUT}s)..."
  
  local poll_interval=30
  local elapsed=0
  local last_output=""
  local idle_count=0
  local max_idle=6  # 3분간 출력 없으면 완료로 간주
  
  while [ $elapsed -lt "$RECOVERY_TIMEOUT" ]; do
    sleep "$poll_interval"
    elapsed=$((elapsed + poll_interval))
    
    # 현재 출력 캡처
    local current_output
    current_output=$(tmux capture-pane -t "$TMUX_SESSION" -p 2>/dev/null | tail -20 || echo "")
    
    # 완료 시그널 체크 (더 정교한 패턴)
    # - "Recovery completed" 또는 "recovery complete"
    # - "Task finished" 또는 "task complete"
    # - 리포트 파일 생성 언급
    # - 명시적 성공 메시지
    if echo "$current_output" | grep -qiE "(recovery (completed|complete|finished)|task (completed|complete|finished)|wrote.*report|gateway.*restored|http 200|✅.*(success|recover|complete))"; then
      log "✅ Claude appears to have completed (detected completion signal)"
      break
    fi
    
    # 출력 변화 체크 (idle detection)
    if [ "$current_output" = "$last_output" ]; then
      idle_count=$((idle_count + 1))
      if [ $idle_count -ge $max_idle ]; then
        log "⚠️ Claude idle for $((idle_count * poll_interval))s, assuming completion"
        break
      fi
    else
      idle_count=0
      last_output="$current_output"
    fi
    
    # 중간 캡처 (매 폴링마다 누적)
    tmux capture-pane -t "$TMUX_SESSION" -p >> "$SESSION_LOG" 2>/dev/null || true
    echo "--- poll at ${elapsed}s ---" >> "$SESSION_LOG"
    
    log "... still working (${elapsed}s elapsed, idle: ${idle_count})"
  done
  
  if [ $elapsed -ge "$RECOVERY_TIMEOUT" ]; then
    log "⚠️ Recovery timeout reached (${RECOVERY_TIMEOUT}s)"
  else
    log "✅ Claude completed in ${elapsed}s (saved $((RECOVERY_TIMEOUT - elapsed))s)"
  fi
  
  # 6. tmux 세션 캡처
  log "Capturing Claude session output..."
  capture_tmux_session "$TMUX_SESSION" "$SESSION_LOG"
  
  # 7. Claude 할당량 체크
  local SUCCESS="unknown"
  
  if ! check_claude_quota "$SESSION_LOG"; then
    send_notification "⚠️ **Level 3 Emergency Recovery 실패**\n\nClaude API 할당량 소진 또는 속도 제한.\n\n다음 단계:\n1. Claude 할당량 확인: \`claude\` → \`/usage\`\n2. 수동 복구 시도\n\n세션 로그: \`$SESSION_LOG\`"
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
    send_notification "✅ **Level 3 Emergency Recovery 성공!**\n\nGateway가 Claude에 의해 복구되었습니다.\n- 복구 시간: ${total_time}초\n- HTTP 상태: $http_code\n- 로그: \`$LOG_FILE\`\n- Claude 세션: \`$SESSION_LOG\`"
    exit 0
  else
    log "🚨 Sending failure notification to Discord..."

    local failure_msg
    failure_msg="🚨 **Level 3 Emergency Recovery 실패!**\n\n**모든 자동 복구 시스템이 실패했습니다:**\n- Level 1 (Watchdog): ❌\n- Level 2 (Health Check): ❌\n- Level 3 (Claude Recovery): ❌\n\n**수동 개입 필요**\n- HTTP 상태: $http_code\n- 복구 시간: ${total_time}초\n- 로그: \`$LOG_FILE\`\n- Claude 세션: \`$SESSION_LOG\`\n- 복구 리포트: \`$REPORT_FILE\` (Claude가 생성했을 경우)"

    send_notification "$failure_msg"

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
