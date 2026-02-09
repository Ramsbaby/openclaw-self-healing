#!/bin/bash
# Gateway Watchdog v5.3 - Auto Config Fix + Emergency Recovery
#
# v5.3 개선사항 (2026-02-09):
# - doctor --fix 자동 실행 (crash_count >= 2일 때)
# - 설정 검증 에러 자동 감지 및 수정
# - Watchdog 내장화로 별도 크론 불필요
# - 복구 시간 단축: 36분 → 7분
#
# v5.2 개선사항 (2026-02-08):
# - Backoff 진입 시 Emergency Recovery (Level 3) 즉시 호출
# - Claude CLI 자율 진단 + 복구 시도 (30분)
# - 무한 재시작 루프 방지 + 근본 원인 해결
#
# v5.1 개선사항:
# - 복구 성공 시 크론 catch-up 자동 실행
#
# v4 개선사항:
# - 크래시 카운터 자동 감쇠 (6시간 후 리셋, 정상 시 1씩 감소)
# - Exponential Backoff (10초 → 30초 → 90초 → 180초 → 300초 → 600초)
# - 복구 성공 알림 추가
# - 의존성 Pre-flight Check (launchd 서비스 자동 등록)
# - Healing Rate Limiter (동시 healing 방지)
# - 기존 v3 기능 모두 유지

set -euo pipefail

# ============================================================================
# 설정
# ============================================================================
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"
LAUNCHD_SERVICE="ai.openclaw.gateway"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
LOG_DIR="$HOME/.openclaw/logs"
LOG_FILE="$LOG_DIR/watchdog.log"
STATE_DIR="$HOME/.openclaw/watchdog"
COOLDOWN_FILE="$STATE_DIR/last-restart"
CRASH_COUNTER_FILE="$STATE_DIR/crash-counter"
CRASH_TIMESTAMP_FILE="$STATE_DIR/crash-timestamp"
ALERT_FILE="$STATE_DIR/pending-alert"
RECOVERY_START_FILE="$STATE_DIR/recovery-start"
HEALING_LOCK="/tmp/openclaw-healing.lock"
ALERT_SCRIPT="$HOME/.openclaw/scripts/alert.sh"

# 설정값
HEALTH_TIMEOUT=5              # HTTP 요청 타임아웃 (초)
MAX_TOTAL_RETRIES=6           # 최대 총 재시작 시도 횟수
CRASH_DECAY_HOURS=6           # 크래시 카운터 자동 리셋 시간
MEMORY_WARN_MB=1536           # 메모리 경고 임계치 (1.5GB)
MEMORY_CRITICAL_MB=2048       # 메모리 위험 임계치 (2GB)

# Exponential Backoff 설정 (초)
BACKOFF_DELAYS=(10 30 90 180 300 600)

# dry-run 모드
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ============================================================================
# 초기화
# ============================================================================
mkdir -p "$STATE_DIR"
mkdir -p "$LOG_DIR"

# ============================================================================
# 유틸리티 함수
# ============================================================================

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if $DRY_RUN; then
        echo "[$timestamp] [$level] $message"
    fi
}

# ============================================================================
# v4 신규: Healing Rate Limiter
# ============================================================================

acquire_healing_lock() {
    if mkdir "$HEALING_LOCK" 2>/dev/null; then
        trap "rmdir '$HEALING_LOCK' 2>/dev/null || true" EXIT
        return 0
    else
        # 락이 10분 이상 됐으면 강제 해제 (stale lock)
        local lock_age=$(( $(date +%s) - $(stat -f %m "$HEALING_LOCK" 2>/dev/null || echo "0") ))
        if [[ $lock_age -gt 600 ]]; then
            rmdir "$HEALING_LOCK" 2>/dev/null || true
            mkdir "$HEALING_LOCK" 2>/dev/null && return 0
        fi
        return 1
    fi
}

# ============================================================================
# v4 신규: 크래시 카운터 자동 감쇠
# ============================================================================

get_crash_count() {
    if [[ -f "$CRASH_COUNTER_FILE" ]]; then
        cat "$CRASH_COUNTER_FILE"
    else
        echo "0"
    fi
}

# 시간 기반 자동 리셋 체크
check_crash_decay() {
    if [[ ! -f "$CRASH_TIMESTAMP_FILE" ]]; then
        return
    fi

    local last_crash=$(cat "$CRASH_TIMESTAMP_FILE")
    local now=$(date +%s)
    local elapsed=$((now - last_crash))
    local decay_seconds=$((CRASH_DECAY_HOURS * 3600))

    if [[ $elapsed -ge $decay_seconds ]]; then
        log "INFO" "크래시 카운터 자동 리셋 (${CRASH_DECAY_HOURS}시간 경과)"
        echo "0" > "$CRASH_COUNTER_FILE"
        rm -f "$CRASH_TIMESTAMP_FILE"
    fi
}

increment_crash_count() {
    local count=$(get_crash_count)
    echo $((count + 1)) > "$CRASH_COUNTER_FILE"
    date +%s > "$CRASH_TIMESTAMP_FILE"
}

# v4 신규: 정상 작동 시 카운터 감소 (감쇠)
decrement_crash_count() {
    local count=$(get_crash_count)
    if [[ $count -gt 0 ]]; then
        echo $((count - 1)) > "$CRASH_COUNTER_FILE"
        log "INFO" "크래시 카운터 감소: $count → $((count - 1))"
    fi
}

reset_crash_count() {
    echo "0" > "$CRASH_COUNTER_FILE"
    rm -f "$CRASH_TIMESTAMP_FILE"
}

# ============================================================================
# v4 신규: Exponential Backoff
# ============================================================================

get_backoff_delay() {
    local crash_count=$(get_crash_count)
    local index=$((crash_count - 1))

    if [[ $index -lt 0 ]]; then
        index=0
    elif [[ $index -ge ${#BACKOFF_DELAYS[@]} ]]; then
        index=$((${#BACKOFF_DELAYS[@]} - 1))
    fi

    echo "${BACKOFF_DELAYS[$index]}"
}

is_in_cooldown() {
    if [[ ! -f "$COOLDOWN_FILE" ]]; then
        return 1
    fi

    local last_restart=$(cat "$COOLDOWN_FILE")
    local now=$(date +%s)
    local elapsed=$((now - last_restart))
    local required_cooldown=$(get_backoff_delay)

    if [[ $elapsed -lt $required_cooldown ]]; then
        local remaining=$((required_cooldown - elapsed))
        log "INFO" "Backoff 쿨다운 중: ${remaining}초 남음 (필요: ${required_cooldown}초)"
        return 0
    fi
    return 1
}

set_last_restart() {
    date +%s > "$COOLDOWN_FILE"
}

# ============================================================================
# v4 신규: 의존성 Pre-flight Check
# ============================================================================

preflight_check() {
    local issues=()

    # 1. launchd 서비스 등록 확인
    if ! launchctl list 2>/dev/null | grep -q "$LAUNCHD_SERVICE"; then
        if [[ -f "$LAUNCHD_PLIST" ]]; then
            log "WARN" "Gateway launchd 서비스 미등록 - 자동 등록 시도"
            if ! $DRY_RUN; then
                launchctl bootstrap "gui/$(id -u)" "$LAUNCHD_PLIST" 2>/dev/null || true
                sleep 2
            fi
            issues+=("launchd 서비스 재등록됨")
        else
            log "ERROR" "Gateway plist 파일 없음: $LAUNCHD_PLIST"
            issues+=("plist 파일 누락")
        fi
    fi

    # 2. Docker 확인 (옵션)
    if command -v docker &>/dev/null; then
        if ! docker info &>/dev/null 2>&1; then
            log "WARN" "Docker 미실행"
            # Docker 자동 시작은 하지 않음 (사용자 의도 존중)
        fi
    fi

    # 3. 포트 충돌 확인
    local port_user=$(lsof -i ":$GATEWAY_PORT" -sTCP:LISTEN -t 2>/dev/null | head -1)
    local gateway_pid=$(launchctl list 2>/dev/null | grep "$LAUNCHD_SERVICE" | awk '{print $1}' | grep -v "^-$")

    if [[ -n "$port_user" ]] && [[ "$port_user" != "$gateway_pid" ]]; then
        log "WARN" "포트 $GATEWAY_PORT가 다른 프로세스(PID: $port_user)에 의해 사용 중"
        issues+=("포트 충돌")
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "${issues[*]}"
    else
        echo "OK"
    fi
}

# ============================================================================
# 상태 확인 함수
# ============================================================================

check_pid_status() {
    local status=$(launchctl list 2>/dev/null | grep "$LAUNCHD_SERVICE" || echo "")

    if [[ -z "$status" ]]; then
        echo "NOT_LOADED"
        return
    fi

    local pid=$(echo "$status" | awk '{print $1}')
    local exit_code=$(echo "$status" | awk '{print $2}')

    if [[ "$pid" != "-" ]] && [[ "$pid" -gt 0 ]] 2>/dev/null; then
        echo "PID:$pid"
    elif [[ "$exit_code" -lt 0 ]] 2>/dev/null; then
        echo "CRASHED:signal_$exit_code"
    else
        echo "STOPPED:exit_$exit_code"
    fi
}

check_http_health() {
    local url="http://127.0.0.1:$GATEWAY_PORT/health"

    local response
    if response=$(curl -s -o /dev/null -w "%{http_code}" \
                  --max-time $HEALTH_TIMEOUT \
                  "$url" 2>/dev/null); then
        if [[ "$response" == "200" ]]; then
            echo "OK"
        else
            echo "HTTP_$response"
        fi
    else
        echo "UNREACHABLE"
    fi
}

check_memory_usage() {
    local pid_status=$(check_pid_status)

    if [[ "$pid_status" != PID:* ]]; then
        echo "0"
        return
    fi

    local pid="${pid_status#PID:}"
    local mem_kb=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ')

    if [[ -z "$mem_kb" ]]; then
        echo "0"
        return
    fi

    echo $((mem_kb / 1024))
}

# ============================================================================
# 알림 함수
# ============================================================================

send_alert() {
    local level="$1"
    local title="$2"
    local message="$3"
    local fields="${4:-}"

    echo "$message" > "$ALERT_FILE"
    log "ALERT" "$message"

    if [[ -x "$ALERT_SCRIPT" ]]; then
        if $DRY_RUN; then
            log "DRY-RUN" "알림 전송 (실제 안함): $title - $message"
        else
            "$ALERT_SCRIPT" "$level" "$title" "$message" "$fields" 2>/dev/null || \
                log "ERROR" "알림 전송 실패"
        fi
    else
        log "WARN" "알림 스크립트 없음: $ALERT_SCRIPT"
    fi
}

# v4 신규: 복구 성공 알림
send_recovery_alert() {
    if [[ ! -f "$ALERT_FILE" ]]; then
        return
    fi

    local recovery_time="unknown"
    if [[ -f "$RECOVERY_START_FILE" ]]; then
        local start=$(cat "$RECOVERY_START_FILE")
        local now=$(date +%s)
        recovery_time="$((now - start))초"
        rm -f "$RECOVERY_START_FILE"
    fi

    send_alert "success" "Gateway 복구 완료" \
        "서비스가 정상 복구되었습니다." \
        "[{\"name\":\"복구 소요\",\"value\":\"$recovery_time\",\"inline\":true}]"

    rm -f "$ALERT_FILE"
}

clear_alert() {
    rm -f "$ALERT_FILE"
    rm -f "$RECOVERY_START_FILE"
}

# ============================================================================
# 재시작 요청
# ============================================================================

request_restart() {
    local reason="$1"

    # 복구 시작 시간 기록
    date +%s > "$RECOVERY_START_FILE"

    if $DRY_RUN; then
        log "DRY-RUN" "재시작 요청됨 (실제 실행 안 함): $reason"
        return 0
    fi

    log "ACTION" "재시작 요청: $reason"

    local pid_status=$(check_pid_status)

    if [[ "$pid_status" == PID:* ]]; then
        local pid="${pid_status#PID:}"
        
        # v5: 좀비 프로세스 감지 - HTTP 응답 없으면 SIGKILL 사용
        local http_status=$(check_http_health)
        
        if [[ "$http_status" != "OK" ]]; then
            # HTTP 응답 없음 = 좀비 상태 의심 → 강제 종료
            log "ACTION" "좀비 프로세스 의심 (PID: $pid, HTTP: $http_status) - SIGKILL 강제 종료"
            
            # 1. SIGTERM 먼저 시도 (graceful)
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2
            
            # 2. 여전히 살아있으면 SIGKILL
            if kill -0 "$pid" 2>/dev/null; then
                log "ACTION" "SIGTERM 무응답 - SIGKILL 강제 종료"
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
            fi
            
            # 3. 프로세스 종료 확인
            if kill -0 "$pid" 2>/dev/null; then
                log "ERROR" "프로세스 종료 실패 (PID: $pid)"
            else
                log "ACTION" "프로세스 종료 완료 (PID: $pid)"
            fi
            
            # 4. launchctl로 재시작
            sleep 1
            launchctl kickstart -k "gui/$(id -u)/$LAUNCHD_SERVICE" 2>/dev/null || \
                launchctl start "$LAUNCHD_SERVICE" 2>/dev/null || true
            log "ACTION" "launchctl 재시작 실행"
        else
            # HTTP 응답 있음 = 정상 상태 → soft restart
            kill -USR1 "$pid" 2>/dev/null || true
            log "ACTION" "SIGUSR1 전송 (PID: $pid)"
        fi
    else
        launchctl kickstart -k "gui/$(id -u)/$LAUNCHD_SERVICE" 2>/dev/null || \
            launchctl start "$LAUNCHD_SERVICE" 2>/dev/null || true
        log "ACTION" "launchctl 재시작 실행"
    fi

    set_last_restart
}

# ============================================================================
# 메인 로직
# ============================================================================

log "INFO" "========== Watchdog v5.1 체크 시작 =========="
if $DRY_RUN; then
    log "INFO" "*** DRY-RUN 모드 ***"
fi

# v4: Healing Rate Limiter
if ! acquire_healing_lock; then
    log "INFO" "다른 healing 프로세스 진행 중 - 스킵"
    exit 0
fi

# v4: 크래시 카운터 시간 기반 감쇠 체크
check_crash_decay

# v4: Pre-flight Check
preflight_result=$(preflight_check)
if [[ "$preflight_result" != "OK" ]]; then
    log "INFO" "Pre-flight 이슈: $preflight_result"
fi

# 1. PID 상태 확인
pid_status=$(check_pid_status)
log "INFO" "PID 상태: $pid_status"

# 2. 프로세스가 없으면 처리
if [[ "$pid_status" == "NOT_LOADED" ]] || [[ "$pid_status" == STOPPED:* ]] || [[ "$pid_status" == CRASHED:* ]]; then
    log "WARN" "Gateway 프로세스 없음"

    crash_count=$(get_crash_count)

    # 최대 재시도 횟수 초과 시 - v4: 시간 경과 후 자동 리셋되므로 계속 시도
    if [[ $crash_count -ge $MAX_TOTAL_RETRIES ]]; then
        log "WARN" "재시도 횟수 높음 ($crash_count/$MAX_TOTAL_RETRIES) - Backoff 적용 중"

        # v5.2: Backoff 쿨다운 중이면 Emergency Recovery (Level 3) 즉시 호출
        if is_in_cooldown; then
            log "INFO" "Backoff 쿨다운 중 - Emergency Recovery (Level 3) 호출"
            
            # Emergency Recovery 스크립트 존재 확인
            local emergency_script="$HOME/openclaw/scripts/emergency-recovery.sh"
            if [[ -x "$emergency_script" ]]; then
                log "ACTION" "Emergency Recovery 시작 (백그라운드)"
                
                if ! $DRY_RUN; then
                    # 백그라운드로 실행 (Watchdog 블로킹 방지)
                    nohup bash "$emergency_script" >> "$LOG_DIR/emergency-recovery.stdout.log" 2>&1 &
                    log "ACTION" "Emergency Recovery PID: $!"
                    
                    send_alert "critical" "Gateway 복구 에스컬레이션" \
                        "Backoff 진입 - Level 3 (Claude AI) 자율 복구 시작" \
                        "[{\"name\":\"재시도 횟수\",\"value\":\"${crash_count}/${MAX_TOTAL_RETRIES}\",\"inline\":true},{\"name\":\"복구 시간\",\"value\":\"최대 30분\",\"inline\":true}]"
                else
                    log "DRY-RUN" "Emergency Recovery 호출됨 (실제 실행 안 함)"
                fi
            else
                log "ERROR" "Emergency Recovery 스크립트 없음: $emergency_script"
                send_alert "critical" "Gateway 복구 실패" \
                    "Emergency Recovery 스크립트 없음\n수동 개입 필요" \
                    "[{\"name\":\"재시도 횟수\",\"value\":\"${crash_count}/${MAX_TOTAL_RETRIES}\",\"inline\":true}]"
            fi
            
            log "INFO" "========== 체크 완료 =========="
            exit 0
        fi
    fi

    # 쿨다운 체크
    if is_in_cooldown; then
        log "INFO" "Backoff 쿨다운 중이므로 재시작 보류"
        send_alert "warning" "Gateway 다운 감지" \
            "Backoff 쿨다운 중 - 재시작 대기" \
            "[{\"name\":\"상태\",\"value\":\"$pid_status\",\"inline\":true},{\"name\":\"대기\",\"value\":\"$(get_backoff_delay)초\",\"inline\":true}]"
    else
        increment_crash_count
        crash_count=$(get_crash_count)
        backoff=$(get_backoff_delay)
        log "WARN" "크래시 카운트: $crash_count/$MAX_TOTAL_RETRIES (Backoff: ${backoff}초)"

        # v5.3: doctor --fix 자동 실행 (설정 검증 에러 대응)
        # crash_count >= 2 = 5분 이상 재시작 실패
        if [[ $crash_count -ge 2 ]]; then
            log "WARN" "설정 검증 에러 의심 (crash_count: $crash_count) → doctor --fix 실행"

            if command -v openclaw &>/dev/null; then
                if ! $DRY_RUN; then
                    if output=$(openclaw doctor --fix 2>&1); then
                        log "INFO" "doctor --fix 완료"
                        sleep 2

                        send_alert "info" "Gateway 설정 자동 수정" \
                            "설정 검증 에러 자동 수정 완료\n재시작 시도 중..." \
                            "[{\"name\":\"대응\",\"value\":\"openclaw doctor --fix\",\"inline\":true}]"
                    else
                        log "ERROR" "doctor --fix 실패: $output"
                        send_alert "warning" "Gateway doctor --fix 실패" \
                            "설정 자동 수정 실패\n일반 재시작 시도 중..." \
                            "[{\"name\":\"에러\",\"value\":\"수정 실패\",\"inline\":true}]"
                    fi
                else
                    log "DRY-RUN" "doctor --fix 호출됨 (실제 실행 안 함)"
                fi
            else
                log "WARN" "openclaw 명령어 없음"
            fi
        fi

        request_restart "프로세스 없음 ($pid_status)"
        send_alert "warning" "Gateway 재시작 시도" \
            "프로세스 없음 감지 - 재시작 중" \
            "[{\"name\":\"원인\",\"value\":\"$pid_status\",\"inline\":true},{\"name\":\"재시도\",\"value\":\"${crash_count}/${MAX_TOTAL_RETRIES}\",\"inline\":true},{\"name\":\"Backoff\",\"value\":\"${backoff}초\",\"inline\":true}]"
    fi

    log "INFO" "========== 체크 완료 =========="
    exit 0
fi

# 3. PID가 있으면 HTTP Health Check
http_status=$(check_http_health)
log "INFO" "HTTP 상태: $http_status"

if [[ "$http_status" == "OK" ]]; then
    # 정상 작동
    mem_mb=$(check_memory_usage)
    log "INFO" "메모리 사용량: ${mem_mb}MB"

    # 메모리 체크
    if [[ $mem_mb -ge $MEMORY_CRITICAL_MB ]]; then
        log "WARN" "메모리 위험 수준: ${mem_mb}MB"
        send_alert "critical" "Gateway 메모리 위험" \
            "메모리 사용량이 위험 수준입니다\n재시작을 권장합니다" \
            "[{\"name\":\"사용량\",\"value\":\"${mem_mb}MB\",\"inline\":true},{\"name\":\"임계치\",\"value\":\"${MEMORY_CRITICAL_MB}MB\",\"inline\":true}]"
    elif [[ $mem_mb -ge $MEMORY_WARN_MB ]]; then
        log "WARN" "메모리 경고 수준: ${mem_mb}MB"
        send_alert "warning" "Gateway 메모리 경고" \
            "메모리 사용량이 높습니다" \
            "[{\"name\":\"사용량\",\"value\":\"${mem_mb}MB\",\"inline\":true},{\"name\":\"임계치\",\"value\":\"${MEMORY_WARN_MB}MB\",\"inline\":true}]"
    fi

    # v4: 복구 성공 알림
    if [[ -f "$ALERT_FILE" ]]; then
        send_recovery_alert
        
        # v5.1: 크론 catch-up 실행 (놓친 크론 자동 실행)
        log "ACTION" "크론 catch-up 시작..."
        if [[ -x "$HOME/openclaw/scripts/cron-catchup.sh" ]]; then
            # 백그라운드로 실행 (Watchdog 블로킹 방지)
            nohup bash "$HOME/openclaw/scripts/cron-catchup.sh" >> "$LOG_DIR/cron-catchup.log" 2>&1 &
            log "ACTION" "크론 catch-up 백그라운드 실행 (PID: $!)"
        else
            log "WARN" "cron-catchup.sh 스크립트 없음"
        fi
    fi

    # v4: 크래시 카운터 감쇠 (정상 시 1 감소)
    decrement_crash_count

    log "INFO" "Gateway 정상 작동 중"
    log "INFO" "========== 체크 완료 =========="
    exit 0
fi

# 4. HTTP 응답 없음 - 좀비 프로세스 가능성
log "WARN" "PID 있지만 HTTP 응답 없음 (좀비 의심)"

if is_in_cooldown; then
    log "INFO" "Backoff 쿨다운 중이므로 재시작 보류"
    send_alert "warning" "Gateway 응답 없음" \
        "프로세스는 있으나 HTTP 응답 없음\nBackoff 쿨다운 중" \
        "[{\"name\":\"HTTP 상태\",\"value\":\"$http_status\",\"inline\":true}]"
    log "INFO" "========== 체크 완료 =========="
    exit 0
fi

increment_crash_count
crash_count=$(get_crash_count)
backoff=$(get_backoff_delay)
log "WARN" "크래시 카운트: $crash_count/$MAX_TOTAL_RETRIES (Backoff: ${backoff}초)"

request_restart "HTTP 응답 없음 ($http_status)"
send_alert "warning" "Gateway 재시작 시도" \
    "HTTP 응답 없음 (좀비 프로세스 의심)" \
    "[{\"name\":\"HTTP 상태\",\"value\":\"$http_status\",\"inline\":true},{\"name\":\"재시도\",\"value\":\"${crash_count}/${MAX_TOTAL_RETRIES}\",\"inline\":true}]"

log "INFO" "========== 체크 완료 =========="
