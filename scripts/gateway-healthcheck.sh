#!/bin/bash

# OpenClaw Gateway Health Check (Level 2 Self-Healing)
# HTTP 응답 검증 → 실패 시 재시작 → 5분 후 재검증 → 실패 시 Level 3 escalation

LOG_FILE=~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log
GATEWAY_URL="http://localhost:18789/"
MAX_RETRIES=3
RETRY_DELAY=30

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
      exit 0
    fi
  done
  
  log "❌ Recovery failed after $MAX_RETRIES retries"
  log "🚨 Escalating to Level 3 (Claude Emergency Recovery)..."
  
  # 5분 대기 후 최종 검증
  sleep 300
  
  if ! check_http; then
    log "🚨 Still unhealthy after 5 minutes, triggering emergency recovery..."
    ~/openclaw/scripts/emergency-recovery.sh
  else
    log "✅ Gateway recovered during waiting period"
  fi
else
  log "✅ Gateway healthy"
fi

log "=== Health Check Completed ==="
