#!/bin/bash
# cron-catchup.sh - Gateway 재시작 후 놓친 크론 자동 실행
# Watchdog v5.1에서 호출됨

set -euo pipefail

LOG_FILE="$HOME/.openclaw/logs/cron-catchup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Cron Catch-up 시작 ==="

# 현재 시간 (밀리초)
NOW_MS=$(($(date +%s) * 1000))

# 놓친 크론 감지 및 실행
MISSED_COUNT=0
EXECUTED_COUNT=0

# OpenClaw CLI로 크론 목록 가져오기
CRONS=$(openclaw cron list --json 2>/dev/null || echo '{"jobs":[]}')

# 각 크론 확인
echo "$CRONS" | jq -c '.jobs[] | select(.enabled == true)' 2>/dev/null | while read -r job; do
    JOB_ID=$(echo "$job" | jq -r '.id')
    JOB_NAME=$(echo "$job" | jq -r '.name')
    NEXT_RUN=$(echo "$job" | jq -r '.state.nextRunAtMs // 0')
    LAST_RUN=$(echo "$job" | jq -r '.state.lastRunAtMs // 0')
    
    # nextRunAtMs가 현재 시간보다 과거이고, 최근 실행이 2시간 이상 전이면 놓친 것
    if [[ "$NEXT_RUN" -gt 0 ]] && [[ "$NEXT_RUN" -lt "$NOW_MS" ]]; then
        if [[ "$LAST_RUN" == "null" ]] || [[ "$LAST_RUN" == "0" ]]; then
            HOURS_SINCE_LAST=999
        else
            HOURS_SINCE_LAST=$(( (NOW_MS - LAST_RUN) / 3600000 ))
        fi
        
        # 마지막 실행이 2시간 이상 전인 경우만 (중복 실행 방지)
        if [[ "$HOURS_SINCE_LAST" -ge 2 ]]; then
            ((MISSED_COUNT++)) || true
            log "놓친 크론 발견: $JOB_NAME (마지막 실행: ${HOURS_SINCE_LAST}시간 전)"
            
            # 크론 수동 실행 (OpenClaw CLI 사용)
            if openclaw cron run "$JOB_ID" 2>/dev/null; then
                log "  → 실행 성공: $JOB_NAME"
                ((EXECUTED_COUNT++)) || true
            else
                log "  → 실행 실패: $JOB_NAME"
            fi
            
            # 과부하 방지 (5초 대기)
            sleep 5
        fi
    fi
done

log "=== Catch-up 완료 ==="
