#!/bin/bash

# OpenClaw Gateway Health Check (Level 2 Self-Healing)
# HTTP 응답 검증 → 실패 시 재시작 → 5분 후 재검증 → 실패 시 Level 3 escalation

# Lock file로 중복 실행 방지
LOCKFILE=/tmp/openclaw-healthcheck.lock
if [ -f "$LOCKFILE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Previous health check still running, skipping..."
  exit 0
fi
touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

LOG_FILE=~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log
GATEWAY_URL="http://localhost:18789/"
MAX_RETRIES=3
RETRY_DELAY=30
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1468429341154214049/arTEGUkhIZ5bpE63AefMnyneomjwf1zDzCpzCwbdlzKpH7KgNzcMpFNX9G-DPW5HRojU"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_http() {
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL" 2>/dev/null)
  if [ "$http_code" = "200" ]; then
    return 0
  else
    log "HTTP check failed: $http_code"
    return 1
  fi
}

restart_gateway() {
  log "Restarting OpenClaw Gateway..."
  openclaw gateway restart >> "$LOG_FILE" 2>&1
  sleep "$RETRY_DELAY"
}

# === Main Logic ===

log "=== Health Check Started ==="

# HTTP 응답 체크 (프로세스 체크 제거 - pgrep 신뢰성 이슈)
if ! check_http; then
  log "⚠️ Gateway unhealthy (HTTP failed)"
  
  # 3번 재시도
  for i in $(seq 1 $MAX_RETRIES); do
    log "Retry $i/$MAX_RETRIES..."
    restart_gateway
    
    if check_http; then
      log "✅ Recovery successful on retry $i"

      # Discord 알림 (복구 성공)
      curl -X POST "$DISCORD_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"✅ **Gateway 복구 성공**\n\nLevel 2 Health Check가 Gateway를 재시작하여 복구했습니다.\n- 재시도 횟수: $i/$MAX_RETRIES\n- 현재 시각: $(date '+%Y-%m-%d %H:%M:%S')\"}" \
        2>/dev/null

      exit 0
    fi
  done
  
  log "❌ Recovery failed after $MAX_RETRIES retries"
  log "🚨 Escalating to Level 3 (Claude Emergency Recovery)..."

  # Discord 알림 (Level 3로 escalation)
  curl -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"⚠️ **Level 2 Health Check 실패**\n\nGateway를 ${MAX_RETRIES}회 재시작했으나 복구 실패.\n5분 후 Level 3 (Claude Emergency Recovery)로 escalation합니다.\n\n현재 시각: $(date '+%Y-%m-%d %H:%M:%S')\"}" \
    2>/dev/null

  # 5분 대기 후 최종 검증
  sleep 300

  if ! check_http; then
    log "🚨 Still unhealthy after 5 minutes, triggering emergency recovery..."

    # Discord 알림 (Level 3 시작)
    curl -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"🚨 **Level 3 Emergency Recovery 시작**\n\n5분 대기 후에도 Gateway 복구 안 됨.\nClaude가 자동으로 진단 및 복구를 시도합니다.\n\n예상 소요 시간: 30분\n현재 시각: $(date '+%Y-%m-%d %H:%M:%S')\"}" \
      2>/dev/null

    ~/openclaw/scripts/emergency-recovery.sh
  else
    log "✅ Gateway recovered during waiting period"

    # Discord 알림 (대기 중 복구됨)
    curl -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"✅ **Gateway 자동 복구됨**\n\n5분 대기 중 Gateway가 스스로 복구되었습니다.\nLevel 3 Emergency Recovery는 실행하지 않습니다.\"}" \
      2>/dev/null
  fi
else
  log "✅ Gateway healthy"
fi

log "=== Health Check Completed ==="
