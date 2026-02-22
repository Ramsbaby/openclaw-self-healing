#!/bin/bash
# Gateway Watchdog v4.2 - Config Auto-Fix 추가
#
# v4.2 개선사항:
# - exit_1 연속 감지 시 openclaw doctor --fix 자동 실행 (config 스키마 불일치 자가복구)
# - 버전 업데이트 후 invalid config로 인한 영구 마비 방지
# - CONFIG_FIX_COUNTER로 중복 실행 방지 (최대 2회)
#
# v4.1 개선사항:
# - Level 3 Emergency Recovery 자동 트리거 (30분 연속 실패 시)
# - Critical failure 추적 및 자동 escalation
# - Emergency Recovery v2 연동
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
CRITICAL_FAILURE_FILE="$STATE_DIR/critical-failure-since"
EMERGENCY_RECOVERY_SCRIPT="$HOME/.openclaw/skills/openclaw-self-healing/scripts/emergency-recovery-v2.sh"
CONFIG_FIX_COUNTER_FILE="$STATE_DIR/config-fix-attempts"
GATEWAY_ERR_LOG="$LOG_DIR/gateway.err.log"

# 설정값
HEALTH_TIMEOUT=5              # HTTP 요청 타임아웃 (초)
MAX_TOTAL_RETRIES=6           # 최대 총 재시작 시도 횟수
CRASH_DECAY_HOURS=6           # 크래시 카운터 자동 리셋 시간
MEMORY_WARN_MB=1536           # 메모리 경고 임계치 (1.5GB)
MEMORY_CRITICAL_MB=2048       # 메모리 위험 임계치 (2GB)
ESCALATE_TO_L3_AFTER=1800     # Level 3 escalation 시간 (30분)

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
# v4.1 신규: Level 3 Escalation
# ============================================================================

check_level3_escalation() {
    local crash_count=$(get_crash_count)

    # Level 3 escalation 조건: MAX_RETRIES 초과 + 30분 이상 지속
    if [[ $crash_count -ge $MAX_TOTAL_RETRIES ]]; then
        if [[ ! -f "$CRITICAL_FAILURE_FILE" ]]; then
            # 처음 임계치 도달 - 타임스탬프 기록
            date +%s > "$CRITICAL_FAILURE_FILE"
            log "WARN" "Critical failure 시작 - Level 3 escalation 대기 중 (${ESCALATE_TO_L3_AFTER}초 후)"
            return 1
        fi

        local failure_start=$(cat "$CRITICAL_FAILURE_FILE")
        local now=$(date +%s)
        local elapsed=$((now - failure_start))

        if [[ $elapsed -ge $ESCALATE_TO_L3_AFTER ]]; then
            log "CRITICAL" "Critical failure ${elapsed}초 지속 - Level 3 Emergency Recovery 트리거"
            return 0
        else
            local remaining=$((ESCALATE_TO_L3_AFTER - elapsed))
            log "INFO" "Critical failure ${elapsed}초 경과 (Level 3까지 ${remaining}초 남음)"
            return 1
        fi
    else
        # 정상 복구 시 critical failure 파일 삭제
        rm -f "$CRITICAL_FAILURE_FILE"
        return 1
    fi
}

trigger_level3_emergency_recovery() {
    log "CRITICAL" "========== ESCALATING TO LEVEL 3 (Emergency Recovery) =========="

    send_alert "critical" "Level 3 Emergency Recovery 트리거" \
        "Watchdog가 ${ESCALATE_TO_L3_AFTER}초 동안 복구 실패\nClaude AI 자동 진단 시작" \
        "[{\"name\":\"재시도 횟수\",\"value\":\"$(get_crash_count)/${MAX_TOTAL_RETRIES}\",\"inline\":true},{\"name\":\"실패 지속\",\"value\":\"${ESCALATE_TO_L3_AFTER}초+\",\"inline\":true}]"

    # Emergency recovery 스크립트 실행
    if [[ -x "$EMERGENCY_RECOVERY_SCRIPT" ]]; then
        if $DRY_RUN; then
            log "DRY-RUN" "Level 3 스크립트 호출 (실제 실행 안 함): $EMERGENCY_RECOVERY_SCRIPT"
        else
            log "ACTION" "Level 3 스크립트 실행: $EMERGENCY_RECOVERY_SCRIPT"
            bash "$EMERGENCY_RECOVERY_SCRIPT" >> "$LOG_FILE" 2>&1 &
            log "INFO" "Level 3 Emergency Recovery 시작됨 (백그라운드)"

            # Critical failure 파일 삭제 (재트리거 방지)
            rm -f "$CRITICAL_FAILURE_FILE"
        fi
    else
        log "ERROR" "Level 3 스크립트 없음: $EMERGENCY_RECOVERY_SCRIPT"
        send_alert "critical" "Level 3 실행 실패" \
            "Emergency recovery 스크립트를 찾을 수 없습니다\n수동 개입 필요" \
            "[{\"name\":\"경로\",\"value\":\"$EMERGENCY_RECOVERY_SCRIPT\"}]"
    fi
}

# ============================================================================
# v4.2 신규: Config 자동 수정 (exit_1 반복 시)
# ============================================================================

is_config_error() {
    # gateway.err.log 마지막 50줄에서 config 오류 패턴 확인
    if [[ ! -f "$GATEWAY_ERR_LOG" ]]; then
        return 1
    fi
    tail -50 "$GATEWAY_ERR_LOG" | grep -q "Config invalid\|Unrecognized keys\|doctor --fix" 2>/dev/null
}

try_config_fix() {
    local fix_count=0
    if [[ -f "$CONFIG_FIX_COUNTER_FILE" ]]; then
        fix_count=$(cat "$CONFIG_FIX_COUNTER_FILE")
    fi

    local MAX_CONFIG_FIX=2
    if [[ $fix_count -ge $MAX_CONFIG_FIX ]]; then
        log "WARN" "Config fix 이미 ${fix_count}회 시도 - 중복 실행 방지 (수동 확인 필요)"
        return 1
    fi

    log "ACTION" "Config 오류 감지 - openclaw doctor --fix 실행 (${fix_count}/${MAX_CONFIG_FIX})"
    echo $((fix_count + 1)) > "$CONFIG_FIX_COUNTER_FILE"

    local doctor_out
    if doctor_out=$(openclaw doctor --fix 2>&1); then
        log "INFO" "doctor --fix 완료"
    else
        # doctor --fix가 non-zero 리턴해도 실제 수정은 됐을 수 있음
        log "INFO" "doctor --fix 출력: ${doctor_out:0:200}"
    fi

    # config에서 직접 invalid key 제거 (doctor --fix가 실제 수정 안 할 경우 대비)
    if is_config_error; then
        log "ACTION" "doctor --fix 미적용 - Python으로 직접 invalid key 제거"
        python3 -c "
import json, sys
try:
    with open('$HOME/.openclaw/openclaw.json') as f:
        c = json.load(f)
    discord = c.get('channels', {}).get('discord', {})
    removed = []
    for key in ['streaming', 'statusReactions']:
        if key in discord:
            del discord[key]
            removed.append(f'channels.discord.{key}')
    with open('$HOME/.openclaw/openclaw.json', 'w') as f:
        json.dump(c, f, indent=2, ensure_ascii=False)
    print('removed:', removed)
except Exception as e:
    print('error:', e, file=sys.stderr)
    sys.exit(1)
" >> "$LOG_FILE" 2>&1 && log "INFO" "직접 제거 완료" || log "ERROR" "직접 제거 실패"
    fi

    send_alert "warning" "Config 자동 수정 실행" \
        "exit_1 반복으로 config 오류 감지\nopclaw doctor --fix 자동 실행됨" \
        "[{\"name\":\"시도 횟수\",\"value\":\"$((fix_count+1))/${MAX_CONFIG_FIX}\",\"inline\":true}]"

    return 0
}

reset_config_fix_counter() {
    rm -f "$CONFIG_FIX_COUNTER_FILE"
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
        kill -USR1 "$pid" 2>/dev/null || true
        log "ACTION" "SIGUSR1 전송 (PID: $pid)"
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

log "INFO" "========== Watchdog v4 체크 시작 =========="
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
# v4.2: CRASHED:signal_* 이어도 HTTP 200이면 child process 살아있는 것 → 스킵
# 단, child orphan 방지: 90분 이상 signal_* 상태 지속 시 강제 재시작
ORPHAN_TIMEOUT=5400  # 90분
ORPHAN_SINCE_FILE="$STATE_DIR/crashed-signal-since"
if [[ "$pid_status" == "NOT_LOADED" ]] || [[ "$pid_status" == STOPPED:* ]] || [[ "$pid_status" == CRASHED:* ]]; then
    _precheck_http=$(check_http_health)
    if [[ "$_precheck_http" == "OK" ]]; then
        # CRASHED:signal_* 상태라면 orphan 타이머 기록/체크
        if [[ "$pid_status" == CRASHED:signal_* ]]; then
            if [[ ! -f "$ORPHAN_SINCE_FILE" ]]; then
                date +%s > "$ORPHAN_SINCE_FILE"
            fi
            _orphan_since=$(cat "$ORPHAN_SINCE_FILE")
            _orphan_elapsed=$(( $(date +%s) - _orphan_since ))
            if [[ $_orphan_elapsed -ge $ORPHAN_TIMEOUT ]]; then
                log "WARN" "Child orphan ${_orphan_elapsed}초 경과(>${ORPHAN_TIMEOUT}s) — 강제 재시작"
                rm -f "$ORPHAN_SINCE_FILE"
                # 아래 재시작 로직으로 진행
            else
                log "INFO" "launchd PID 없음(${pid_status})이나 HTTP 200 확인 — child process 정상 작동 중 (${_orphan_elapsed}s/${ORPHAN_TIMEOUT}s), 재시작 스킵"
                log "INFO" "========== 체크 완료 =========="
                exit 0
            fi
        else
            rm -f "$ORPHAN_SINCE_FILE"
            log "INFO" "launchd PID 없음(${pid_status})이나 HTTP 200 확인 — child process 정상 작동 중, 재시작 스킵"
            log "INFO" "========== 체크 완료 =========="
            exit 0
        fi
    else
        rm -f "$ORPHAN_SINCE_FILE"
    fi
    log "WARN" "Gateway 프로세스 없음 (HTTP: ${_precheck_http})"

    crash_count=$(get_crash_count)

    # 최대 재시도 횟수 초과 시 - v4.1: Level 3 escalation 체크 추가
    if [[ $crash_count -ge $MAX_TOTAL_RETRIES ]]; then
        log "WARN" "재시도 횟수 높음 ($crash_count/$MAX_TOTAL_RETRIES) - Backoff 적용 중"

        # v4.1: Level 3 escalation 체크
        if check_level3_escalation; then
            trigger_level3_emergency_recovery
            log "INFO" "========== 체크 완료 (Level 3 트리거됨) =========="
            exit 0
        fi

        # v4: 안전 모드 대신 긴 backoff로 계속 시도
        if is_in_cooldown; then
            log "INFO" "Backoff 쿨다운 중 - 다음 주기에 재시도"
            send_alert "warning" "Gateway 복구 지연" \
                "Exponential Backoff 적용 중\n${CRASH_DECAY_HOURS}시간 후 자동 리셋됩니다." \
                "[{\"name\":\"재시도 횟수\",\"value\":\"${crash_count}/${MAX_TOTAL_RETRIES}\",\"inline\":true},{\"name\":\"다음 시도\",\"value\":\"$(get_backoff_delay)초 후\",\"inline\":true}]"
            log "INFO" "========== 체크 완료 =========="
            exit 0
        fi
    fi

    # v4.2: exit_1 감지 시 config 오류 자동 수정
    if [[ "$pid_status" == "STOPPED:exit_1" ]] && is_config_error; then
        log "WARN" "exit_1 + Config 오류 패턴 감지 - 자동 수정 시도"
        try_config_fix
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
    fi

    # v4: 크래시 카운터 감쇠 (정상 시 1 감소)
    decrement_crash_count

    # v4.1: Critical failure 상태 초기화
    rm -f "$CRITICAL_FAILURE_FILE"

    # v4.2: Config fix 카운터 리셋 (정상 복구 확인)
    reset_config_fix_counter

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
