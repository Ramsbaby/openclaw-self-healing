#!/bin/bash
# cron-catchup.sh - Gateway 재시작 후 놓친 크론 자동 실행
# Watchdog v5에서 호출됨

set -euo pipefail

LOG_FILE="$HOME/.openclaw/logs/cron-catchup.log"
GATEWAY_URL="http://localhost:18789"
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 토큰 확인
if [[ -z "$GATEWAY_TOKEN" ]]; then
    GATEWAY_TOKEN=$(jq -r '.OPENCLAW_GATEWAY_TOKEN // empty' ~/.openclaw/openclaw.json 2>/dev/null || echo "")
fi

if [[ -z "$GATEWAY_TOKEN" ]]; then
    log "ERROR: Gateway token not found"
    exit 1
fi

log "=== Cron Catch-up 시작 ==="

# 현재 시간 (밀리초)
NOW_MS=$(($(date +%s) * 1000))

# 크론 목록 가져오기
CRONS=$(curl -s -H "Authorization: Bearer $GATEWAY_TOKEN" "$GATEWAY_URL/api/cron/jobs" 2>/dev/null)

if [[ -z "$CRONS" ]] || [[ "$CRONS" == "null" ]]; then
    log "ERROR: Failed to fetch cron jobs"
    exit 1
fi

# 놓친 크론 찾기 및 실행
MISSED_COUNT=0
EXECUTED_COUNT=0

echo "$CRONS" | jq -c '.jobs[] | select(.enabled == true)' | while read -r job; do
    JOB_ID=$(echo "$job" | jq -r '.id')
    JOB_NAME=$(echo "$job" | jq -r '.name')
    NEXT_RUN=$(echo "$job" | jq -r '.state.nextRunAtMs // 0')
    LAST_RUN=$(echo "$job" | jq -r '.state.lastRunAtMs // 0')
    
    # nextRunAtMs가 현재 시간보다 과거이고, 최근 실행이 24시간 이상 전이면 놓친 것
    if [[ "$NEXT_RUN" -gt 0 ]] && [[ "$NEXT_RUN" -lt "$NOW_MS" ]]; then
        HOURS_SINCE_LAST=$(( (NOW_MS - LAST_RUN) / 3600000 ))
        
        # 마지막 실행이 2시간 이상 전인 경우만 (중복 실행 방지)
        if [[ "$HOURS_SINCE_LAST" -ge 2 ]]; then
            ((MISSED_COUNT++)) || true
            log "놓친 크론 발견: $JOB_NAME (마지막 실행: ${HOURS_SINCE_LAST}시간 전)"
            
            # 크론 수동 실행
            RESULT=$(curl -s -X POST \
                -H "Authorization: Bearer $GATEWAY_TOKEN" \
                -H "Content-Type: application/json" \
                "$GATEWAY_URL/api/cron/jobs/$JOB_ID/run" 2>/dev/null)
            
            if echo "$RESULT" | grep -q "ok\|success\|triggered"; then
                log "  → 실행 성공: $JOB_NAME"
                ((EXECUTED_COUNT++)) || true
            else
                log "  → 실행 실패: $JOB_NAME - $RESULT"
            fi
            
            # 과부하 방지 (3초 대기)
            sleep 3
        fi
    fi
done

log "=== Catch-up 완료: 놓친 크론 $MISSED_COUNT개, 실행 $EXECUTED_COUNT개 ==="
