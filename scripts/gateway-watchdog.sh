#!/bin/bash
# Gateway Watchdog v5.4 - Auto Config Fix + Validation + Auto Halt
#
# v5.4 개선사항 (2026-02-09):
# - doctor --fix 후 **설정 재검증** (jq JSON 파싱)
# - doctor --fix 2회 실패 → **자동 중단 + 수동 개입 신호**
# - crash >= 5 → 무한 루프 방지 자동 중단
# - 명확한 실패 상황 로깅
# - 관훈문제 08:12 상황 재발 방지
#
# v5.3 개선사항 (2026-02-09):
# - doctor --fix 자동 실행 (crash_count >= 2일 때)
# - 설정 검증 에러 자동 감지 및 수정
#
# v5.2 개선사항:
# - Backoff 진입 시 Emergency Recovery (Level 3) 즉시 호출
# - Claude CLI 자율 진단 + 복구 시도 (30분)
# - 무한 재시작 루프 방지 + 근본 원인 해결
#
# v5.1 개선사항:
# - 복구 성공 시 크론 catch-up 자동 실행

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

# v5.4 신규: doctor --fix 추적
DOCTOR_FIX_ATTEMPTS_FILE="$STATE_DIR/doctor-fix-attempts"
DOCTOR_FIX_MAX_ATTEMPTS=2  # doctor --fix 최대 2회 시도
CRASH_HALT_THRESHOLD=5     # crash 5회 이상 = 자동 중단

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

# 테스트 모드 (시뮬레이션)
TEST_SCENARIO="${TEST_SCENARIO:-}"  # "halt-crash", "halt-doctor", "normal"

# ============================================================================
# 초기화
# ============================================================================
mkdir -p "$STATE_DIR"
mkdir -p "$LOG_DIR"

# ============================================================================
# 유틸리티 함수
# ============================================================================

# Emergency Recovery 트리거 (중복 실행 방지 포함)
trigger_emergency_recovery() {
    local reason="$1"

    # 1. 기존 Emergency Recovery 세션 확인
    if tmux list-sessions 2>/dev/null | grep -q "emergency_recovery_"; then
        log "WARN" "Emergency Recovery 이미 실행 중 - 중복 트리거 방지"
        return 0
    fi

    # 2. Lock 파일 확인 (30분 타임아웃)
    if [[ -f "$HEALING_LOCK" ]]; then
        local lock_time=$(cat "$HEALING_LOCK" 2>/dev/null || echo "0")
        local now=$(date +%s)
        local elapsed=$((now - lock_time))
        if [[ $elapsed -lt 1800 ]]; then
            log "WARN" "Emergency Recovery lock 활성 (${elapsed}s 전) - 중복 트리거 방지"
            return 0
        else
            log "WARN" "Emergency Recovery lock 만료 (${elapsed}s) - 제거 후 재실행"
            rm -f "$HEALING_LOCK"
        fi
    fi

    # 3. Lock 설정
    date +%s > "$HEALING_LOCK"

    # 4. Emergency Recovery 실행
    RECOVERY_SCRIPT="$HOME/openclaw/scripts/emergency-recovery-v2.sh"
    if [[ -x "$RECOVERY_SCRIPT" ]]; then
        if ! $DRY_RUN; then
            "$RECOVERY_SCRIPT" >> "$LOG_DIR/emergency-recovery-trigger.log" 2>&1 &
            log "INFO" "Emergency Recovery 백그라운드 실행 시작 (PID: $!)"
        else
            log "DRY-RUN" "Emergency Recovery 호출됨 (실제 실행 안 함)"
        fi
    else
        log "ERROR" "Emergency Recovery 스크립트 없음: $RECOVERY_SCRIPT"
        send_alert "error" "Level 3 실패" "Emergency Recovery 스크립트를 찾을 수 없습니다." "[]"
        rm -f "$HEALING_LOCK"
        return 1
    fi
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if $DRY_RUN; then
        echo "[$timestamp] [$level] $message"
    fi
}

# v5.4 신규: doctor --fix 시도 횟수 추적
get_doctor_fix_attempts() {
    if [[ -f "$DOCTOR_FIX_ATTEMPTS_FILE" ]]; then
        cat "$DOCTOR_FIX_ATTEMPTS_FILE"
    else
        echo "0"
    fi
}

increment_doctor_fix_attempts() {
    local attempts=$(get_doctor_fix_attempts)
    echo $((attempts + 1)) > "$DOCTOR_FIX_ATTEMPTS_FILE"
}

reset_doctor_fix_attempts() {
    echo "0" > "$DOCTOR_FIX_ATTEMPTS_FILE"
}

# v5.4 신규: 설정 검증 (JSON 파싱 + 구문 체크)
validate_config() {
    local config_file="$HOME/.openclaw/openclaw.json"
    
    if [[ ! -f "$config_file" ]]; then
        log "ERROR" "설정 파일 없음: $config_file"
        return 1
    fi
    
    # 1. JSON 구문 검증
    if ! jq . "$config_file" > /dev/null 2>&1; then
        log "ERROR" "설정 파일 JSON 구문 에러"
        return 1
    fi
    
    # 2. 알려진 잘못된 키 검사 (jq -e: null/false → exit 1)
    local config=$(cat "$config_file")

    # tools.exec.allowlist (deprecated, 08:12 사고 원인)
    if echo "$config" | jq -e '.tools.exec.allowlist' &>/dev/null; then
        log "ERROR" "잘못된 설정: tools.exec.allowlist (deprecated)"
        return 1
    fi

    # tools.allowlist (deprecated)
    if echo "$config" | jq -e '.tools.allowlist' &>/dev/null; then
        log "ERROR" "잘못된 설정: tools.allowlist (deprecated)"
        return 1
    fi

    # gateway 섹션 검증 (필수 키)
    if ! echo "$config" | jq -e '.gateway' &>/dev/null; then
        log "ERROR" "설정 파일에서 gateway 섹션 부재"
        return 1
    fi
    
    log "INFO" "설정 파일 검증 성공"
    return 0
}

# v5.4 신규: doctor --fix + 재검증 로직
attempt_doctor_fix() {
    local attempts=$(get_doctor_fix_attempts)
    
    # 이미 2회 시도했으면 실행 안 함
    if [[ $attempts -ge $DOCTOR_FIX_MAX_ATTEMPTS ]]; then
        log "WARN" "doctor --fix 최대 시도 횟수 초과 ($attempts/$DOCTOR_FIX_MAX_ATTEMPTS)"
        return 1
    fi
    
    log "INFO" "doctor --fix 시도 ($((attempts + 1))/$DOCTOR_FIX_MAX_ATTEMPTS)"
    
    # 1. doctor --fix 실행
    if ! $DRY_RUN; then
        local output
        if ! output=$(openclaw doctor --fix 2>&1); then
            log "ERROR" "doctor --fix 실행 실패"
            increment_doctor_fix_attempts
            return 1
        fi
        log "INFO" "doctor --fix 실행 완료: $output"
    else
        log "DRY-RUN" "doctor --fix 호출됨 (실제 실행 안 함)"
    fi
    
    # 2. 대기 (설정 적용 시간)
    sleep 3
    
    # 3. 설정 재검증
    if validate_config; then
        log "INFO" "설정 재검증 성공"
        reset_doctor_fix_attempts
        return 0
    else
        log "ERROR" "설정 재검증 실패 - doctor --fix가 효과 없음"
        increment_doctor_fix_attempts
        return 1
    fi
}

# ============================================================================
# 크래시 카운터 자동 감쇠
# ============================================================================

get_crash_count() {
    if [[ -f "$CRASH_COUNTER_FILE" ]]; then
        cat "$CRASH_COUNTER_FILE"
    else
        echo "0"
    fi
}

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
        reset_doctor_fix_attempts
    fi
}

increment_crash_count() {
    local count=$(get_crash_count)
    echo $((count + 1)) > "$CRASH_COUNTER_FILE"
    date +%s > "$CRASH_TIMESTAMP_FILE"
}

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
    reset_doctor_fix_attempts
}

# ============================================================================
# Exponential Backoff
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
        log "INFO" "Backoff 쿨다운 중: ${remaining}초 남음"
        return 0
    fi
    return 1
}

set_last_restart() {
    date +%s > "$COOLDOWN_FILE"
}

# ============================================================================
# 의존성 Pre-flight Check
# ============================================================================

preflight_check() {
    local issues=()

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
    # 테스트 모드: 시나리오 시뮬레이션
    if [[ "$TEST_SCENARIO" == "halt-crash" ]] || [[ "$TEST_SCENARIO" == "halt-doctor" ]]; then
        echo "STOPPED:exit_1"
        return
    fi
    
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
            log "DRY-RUN" "알림: $title - $message"
        else
            "$ALERT_SCRIPT" "$level" "$title" "$message" "$fields" 2>/dev/null || \
                log "ERROR" "알림 전송 실패"
        fi
    else
        log "WARN" "알림 스크립트 없음: $ALERT_SCRIPT"
    fi
}

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

# ============================================================================
# 재시작 요청
# ============================================================================

request_restart() {
    local reason="$1"

    date +%s > "$RECOVERY_START_FILE"

    if $DRY_RUN; then
        log "DRY-RUN" "재시작 요청됨: $reason"
        return 0
    fi

    log "ACTION" "재시작 요청: $reason"

    local pid_status=$(check_pid_status)

    if [[ "$pid_status" == PID:* ]]; then
        local pid="${pid_status#PID:}"
        local http_status=$(check_http_health)
        
        if [[ "$http_status" != "OK" ]]; then
            log "ACTION" "좀비 프로세스 의심 (PID: $pid) - 강제 종료"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2
            
            if kill -0 "$pid" 2>/dev/null; then
                log "ACTION" "SIGKILL 강제 종료"
                kill -9 "$pid" 2>/dev/null || true
            fi
            
            sleep 1
            launchctl kickstart -k "gui/$(id -u)/$LAUNCHD_SERVICE" 2>/dev/null || \
                launchctl start "$LAUNCHD_SERVICE" 2>/dev/null || true
        else
            kill -USR1 "$pid" 2>/dev/null || true
            log "ACTION" "SIGUSR1 전송 (soft restart)"
        fi
    else
        launchctl kickstart -k "gui/$(id -u)/$LAUNCHD_SERVICE" 2>/dev/null || \
            launchctl start "$LAUNCHD_SERVICE" 2>/dev/null || true
    fi

    set_last_restart
}

# ============================================================================
# 메인 로직
# ============================================================================

log "INFO" "========== Watchdog v5.4 체크 시작 =========="

check_crash_decay

pid_status=$(check_pid_status)
log "INFO" "PID 상태: $pid_status"

# 프로세스 없음
if [[ "$pid_status" == "NOT_LOADED" ]] || [[ "$pid_status" == STOPPED:* ]] || [[ "$pid_status" == CRASHED:* ]]; then
    log "WARN" "Gateway 프로세스 없음"

    crash_count=$(get_crash_count)
    
    # v5.4: 무한 루프 방지 - crash >= 5 → Emergency Recovery (Level 3)
    if [[ $crash_count -ge $CRASH_HALT_THRESHOLD ]]; then
        log "ERROR" "🚨 crash 임계치 도달 ($crash_count >= $CRASH_HALT_THRESHOLD)"
        log "WARN" "Level 1 (Watchdog) 실패, Level 2 (doctor --fix) 실패"
        log "WARN" "Level 3 (Emergency PTY Recovery) 시작..."

        send_alert "critical" "🚨 Gateway 무한 루프 → Level 3 트리거" \
            "Gateway가 ${crash_count}회 연속 실패했습니다.\n\nLevel 3 Emergency Recovery (Claude 자율 복구) 시작...\n\n진행 상황은 Discord로 알림됩니다." \
            "[{\"name\":\"crash 횟수\",\"value\":\"${crash_count}/${CRASH_HALT_THRESHOLD}\",\"inline\":true},{\"name\":\"Level 3\",\"value\":\"시작 중\",\"inline\":true}]"

        trigger_emergency_recovery "crash 임계치 도달 ($crash_count)"

        log "INFO" "========== 체크 완료 (Level 3 트리거됨) =========="
        exit 0
    fi

    # 쿨다운 체크
    if is_in_cooldown; then
        log "INFO" "Backoff 쿨다운 중 - 재시작 보류"
        send_alert "warning" "Gateway 다운 감지 (쿨다운 중)" \
            "Backoff 쿨다운 중 - 재시작 대기" \
            "[{\"name\":\"상태\",\"value\":\"$pid_status\",\"inline\":true}]"
    else
        increment_crash_count
        crash_count=$(get_crash_count)
        
        log "WARN" "크래시 카운트: $crash_count/$CRASH_HALT_THRESHOLD"
        
        # v5.4: doctor --fix 실행 (crash >= 2 AND attempts < 2)
        if [[ $crash_count -ge 2 ]]; then
            attempts=$(get_doctor_fix_attempts)
            
            if [[ $attempts -lt $DOCTOR_FIX_MAX_ATTEMPTS ]]; then
                log "WARN" "설정 검증 에러 의심 - doctor --fix 시도"
                
                if attempt_doctor_fix; then
                    # doctor --fix 성공
                    log "INFO" "doctor --fix 성공 - 재시작 진행"
                    send_alert "info" "Gateway 설정 자동 수정 성공" \
                        "doctor --fix로 설정이 고쳐졌습니다.\n재시작 중입니다." \
                        "[{\"name\":\"상태\",\"value\":\"설정 수정 완료\",\"inline\":true}]"
                else
                    # doctor --fix 실패
                    attempts=$(get_doctor_fix_attempts)
                    
                    if [[ $attempts -ge $DOCTOR_FIX_MAX_ATTEMPTS ]]; then
                        log "ERROR" "doctor --fix 최대 시도 횟수 초과"
                        log "WARN" "Level 2 (doctor --fix) 실패 → Level 3 시작..."

                        send_alert "critical" "⚠️ doctor --fix 실패 → Level 3" \
                            "doctor --fix가 ${attempts}회 시도했으나 설정 문제 해결 불가\n\nLevel 3 Emergency Recovery (Claude 자율 복구) 시작..." \
                            "[{\"name\":\"실패 원인\",\"value\":\"설정 재검증 실패\",\"inline\":true},{\"name\":\"Level 3\",\"value\":\"시작 중\",\"inline\":true}]"

                        trigger_emergency_recovery "doctor --fix 실패 (${attempts}회)"

                        log "INFO" "========== 체크 완료 (Level 3 트리거됨) =========="
                        exit 0
                    else
                        log "WARN" "doctor --fix 실패 ($attempts/$DOCTOR_FIX_MAX_ATTEMPTS) - 일반 재시작 시도"
                        send_alert "warning" "doctor --fix 재시도 예정" \
                            "doctor --fix 실패했습니다.\n다음 cycle에 재시도합니다." \
                            "[{\"name\":\"시도\",\"value\":\"${attempts}/${DOCTOR_FIX_MAX_ATTEMPTS}\",\"inline\":true}]"
                    fi
                fi
            else
                # doctor --fix 이미 최대 시도 횟수 도달 → Level 3
                log "ERROR" "doctor --fix 최대 시도 횟수 초과 ($attempts/$DOCTOR_FIX_MAX_ATTEMPTS)"
                log "WARN" "Level 2 실패 → Level 3 Emergency Recovery 시작..."

                send_alert "critical" "⚠️ doctor --fix 실패 → Level 3" \
                    "doctor --fix가 ${attempts}회 시도했으나 설정 문제 해결 불가\n\nLevel 3 Emergency Recovery (Claude 자율 복구) 시작..." \
                    "[{\"name\":\"상태\",\"value\":\"설정 재검증 실패\",\"inline\":true},{\"name\":\"Level 3\",\"value\":\"시작 중\",\"inline\":true}]"

                trigger_emergency_recovery "doctor --fix 최대 시도 초과 (${attempts}회)"

                log "INFO" "========== 체크 완료 (Level 3 트리거됨) =========="
                exit 0
            fi
        fi
        
        request_restart "프로세스 없음 ($pid_status)"
        send_alert "warning" "Gateway 재시작 시도" \
            "프로세스 없음 감지 - 재시작 중" \
            "[{\"name\":\"상태\",\"value\":\"$pid_status\",\"inline\":true}]"
    fi

    log "INFO" "========== 체크 완료 =========="
    exit 0
fi

# PID 있음 → HTTP 헬스 체크
http_status=$(check_http_health)
log "INFO" "HTTP 상태: $http_status"

if [[ "$http_status" == "OK" ]]; then
    # 정상 작동
    mem_mb=$(check_memory_usage)
    log "INFO" "메모리: ${mem_mb}MB"

    if [[ -f "$ALERT_FILE" ]]; then
        send_recovery_alert
    fi

    decrement_crash_count
    reset_doctor_fix_attempts

    log "INFO" "Gateway 정상 작동 중"
    log "INFO" "========== 체크 완료 =========="
    exit 0
fi

# HTTP 응답 없음 → 좀비 프로세스
log "WARN" "HTTP 응답 없음 (좀비 의심)"

if is_in_cooldown; then
    log "INFO" "쿨다운 중 - 보류"
else
    increment_crash_count
    crash_count=$(get_crash_count)
    
    log "WARN" "크래시 카운트: $crash_count/$CRASH_HALT_THRESHOLD"
    
    request_restart "HTTP 응답 없음"
    send_alert "warning" "Gateway 응답 없음 - 재시작 시도" \
        "프로세스는 있으나 HTTP 응답 없음\n(좀비 프로세스 의심)" \
        "[{\"name\":\"상태\",\"value\":\"$http_status\",\"inline\":true}]"
fi

log "INFO" "========== 체크 완료 =========="
