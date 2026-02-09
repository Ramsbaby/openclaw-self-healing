#!/bin/bash
# Config Validator - Gateway 시작 전 Config 검증 및 자동 수정
# Level 0: Config Guardian (Self-Healing System의 최전방)
#
# v1.0 - 2026-02-08
# - openclaw doctor 자동 실행
# - Invalid config key 자동 제거
# - Schema validation
# - Config 변경 시 자동 backup

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
CONFIG_FILE="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
BACKUP_DIR="$HOME/.openclaw/config-backups"
LOG_DIR="${OPENCLAW_LOG_DIR:-$HOME/.openclaw/logs}"
LOG_FILE="$LOG_DIR/config-validator.log"
ALERT_SCRIPT="$HOME/.openclaw/scripts/alert.sh"

# Create directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

# ============================================================================
# Functions
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

backup_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR: Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/openclaw-${timestamp}.json"
    
    cp "$CONFIG_FILE" "$backup_file"
    log "INFO: Config backed up to: $backup_file"
    
    # Keep only last 10 backups
    local backup_count=$(ls -1 "$BACKUP_DIR"/openclaw-*.json 2>/dev/null | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        ls -1t "$BACKUP_DIR"/openclaw-*.json | tail -n +11 | xargs rm -f
        log "INFO: Cleaned old backups (kept last 10)"
    fi
}

validate_config() {
    log "INFO: Running openclaw doctor..."
    
    local doctor_output
    if doctor_output=$(openclaw doctor 2>&1); then
        log "INFO: Config validation passed"
        return 0
    else
        log "WARN: Config validation found issues"
        echo "$doctor_output" >> "$LOG_FILE"
        return 1
    fi
}

auto_fix_config() {
    log "INFO: Running openclaw doctor --fix..."
    
    # Backup before fix
    backup_config
    
    local fix_output
    if fix_output=$(openclaw doctor --fix 2>&1); then
        log "INFO: Config auto-fix completed"
        echo "$fix_output" >> "$LOG_FILE"
        
        # Send success alert
        if [[ -x "$ALERT_SCRIPT" ]]; then
            "$ALERT_SCRIPT" "info" "Config 자동 수정" \
                "Invalid config keys 자동 제거됨\nBackup: $BACKUP_DIR" \
                "" 2>/dev/null || true
        fi
        
        return 0
    else
        log "ERROR: Config auto-fix failed"
        echo "$fix_output" >> "$LOG_FILE"
        
        # Send error alert
        if [[ -x "$ALERT_SCRIPT" ]]; then
            "$ALERT_SCRIPT" "error" "Config 수정 실패" \
                "openclaw doctor --fix 실패\n수동 확인 필요" \
                "" 2>/dev/null || true
        fi
        
        return 1
    fi
}

check_config_syntax() {
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log "ERROR: Config is not valid JSON"
        
        if [[ -x "$ALERT_SCRIPT" ]]; then
            "$ALERT_SCRIPT" "critical" "Config JSON 문법 오류" \
                "Config 파일이 유효한 JSON이 아닙니다\n수동 확인 필요" \
                "" 2>/dev/null || true
        fi
        
        return 1
    fi
    
    log "INFO: Config JSON syntax valid"
    return 0
}

# ============================================================================
# Main Logic
# ============================================================================

log "========== Config Validator Started =========="

# 1. Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# 2. Check JSON syntax
if ! check_config_syntax; then
    log "ERROR: Config validation failed (JSON syntax)"
    exit 1
fi

# 3. Run openclaw doctor
if ! validate_config; then
    log "WARN: Config validation failed - attempting auto-fix"
    
    # 4. Auto-fix if validation failed
    if auto_fix_config; then
        log "INFO: Config auto-fix successful"
        
        # 5. Re-validate after fix
        if validate_config; then
            log "INFO: Config validation passed after fix"
        else
            log "ERROR: Config validation still failing after fix"
            exit 1
        fi
    else
        log "ERROR: Config auto-fix failed"
        exit 1
    fi
else
    log "INFO: Config validation passed"
fi

log "========== Config Validator Completed =========="
exit 0
