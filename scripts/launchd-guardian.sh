#!/bin/bash
# LaunchAgent Guardian - "Who watches the watchman?" 해결
# Cron에서 실행 (launchd와 독립적)
# 핵심 LaunchAgent가 언로드되면 자동 재등록
#
# v1.2 - 2026-02-07
# v1.1: 매시 정각에 heartbeat 로그 (cron 동작 확인용)
# v1.2: PID 체크 추가 - "로드되었지만 실행 안됨" 상태 감지 및 kickstart

set -euo pipefail

LOG_FILE="$HOME/.openclaw/logs/launchd-guardian.log"
PLIST_DIR="$HOME/Library/LaunchAgents"
USER_ID=$(id -u)

# 감시 대상 서비스 (우선순위 순: watchdog → gateway)
SERVICES=(
    "ai.openclaw.watchdog"
    "ai.openclaw.gateway"
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 매시 정각(분=00,01,02)에만 heartbeat 로그 → 로그 과다 방지 + cron 동작 확인
CURRENT_MIN=$(date '+%M')
if [[ "$CURRENT_MIN" == "00" || "$CURRENT_MIN" == "01" || "$CURRENT_MIN" == "02" ]]; then
    log "[HEARTBEAT] guardian cron 정상 동작"
fi

reloaded=0

for service in "${SERVICES[@]}"; do
    plist="$PLIST_DIR/${service}.plist"

    # plist 파일 존재 확인
    if [[ ! -f "$plist" ]]; then
        log "[SKIP] $service - plist 없음: $plist"
        continue
    fi

    # launchd 등록 상태 확인
    list_output=$(launchctl list 2>/dev/null | grep "$service" || true)

    if [[ -z "$list_output" ]]; then
        # 미등록 → 재등록
        log "[WARN] $service 미등록 감지 - 재등록 시도"

        if launchctl bootstrap "gui/$USER_ID" "$plist" 2>/dev/null; then
            log "[OK] $service 재등록 성공"
            reloaded=$((reloaded + 1))
        else
            # bootstrap 실패 시 legacy 방식 시도
            if launchctl load "$plist" 2>/dev/null; then
                log "[OK] $service 재등록 성공 (legacy load)"
                reloaded=$((reloaded + 1))
            else
                log "[ERROR] $service 재등록 실패"
            fi
        fi
    else
        # 등록되어 있음 - PID 체크 (StartInterval 서비스 hang 감지)
        pid=$(echo "$list_output" | awk '{print $1}')

        if [[ "$pid" == "-" ]]; then
            # StartInterval 서비스가 실행 안됨 → kickstart
            log "[WARN] $service 실행 안됨 (PID: -) - kickstart 시도"
            if launchctl kickstart -k "gui/$USER_ID/$service" 2>/dev/null; then
                log "[OK] $service kickstart 성공"
                reloaded=$((reloaded + 1))
            else
                log "[ERROR] $service kickstart 실패"
            fi
        fi
    fi
done

# 재등록된 서비스가 있으면 Discord 알림
if [[ $reloaded -gt 0 ]]; then
    log "[ALERT] ${reloaded}개 서비스 재등록됨"

    ALERT_SCRIPT="$HOME/.openclaw/scripts/alert.sh"
    if [[ -x "$ALERT_SCRIPT" ]]; then
        "$ALERT_SCRIPT" "warning" "LaunchAgent 자동 복구" \
            "${reloaded}개 서비스가 launchd에서 언로드되어 자동 재등록했습니다." \
            "" 2>/dev/null || true
    fi
fi
