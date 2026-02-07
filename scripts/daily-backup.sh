#!/bin/bash
# OpenClaw Daily Backup Script
# 매일 새벽 3시에 실행

set -euo pipefail

# Load self-review library (V5.0.1 AOP)
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib/self-review-lib.sh"

# Self-review metrics
START_TIME=$(date +%s)

BACKUP_DIR=~/openclaw/backups
DATE=$(date +%Y%m%d-%H%M)
BACKUP_NAME="backup-${DATE}-DAILY"
LOG_FILE=~/.openclaw/logs/backup.log

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Main backup logic
main() {

log "=== Backup Started ==="

# 백업 대상 디렉토리
TARGETS=(
    "$HOME/openclaw"
    "$HOME/.openclaw/openclaw.json"
    "$HOME/.openclaw/agents"
    "$HOME/clawd/scripts"
)

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 파일 복사
for target in "${TARGETS[@]}"; do
    if [ -e "$target" ]; then
        cp -r "$target" "$TEMP_DIR/" 2>/dev/null || true
    fi
done

# 압축
cd "$TEMP_DIR"
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tgz" . 2>/dev/null

# GPG 암호화 (암호 파일이 있는 경우)
if [ -f ~/.openclaw/.backup-passphrase ]; then
    gpg --batch --yes --symmetric --cipher-algo AES256 \
        --passphrase-file ~/.openclaw/.backup-passphrase \
        "${BACKUP_DIR}/${BACKUP_NAME}.tgz"
    rm "${BACKUP_DIR}/${BACKUP_NAME}.tgz"
    log "Backup encrypted: ${BACKUP_NAME}.tgz.gpg"
else
    log "Backup created (unencrypted): ${BACKUP_NAME}.tgz"
fi

# 7일 이상 된 백업 삭제
find "$BACKUP_DIR" -name "backup-*.tgz*" -mtime +7 -delete 2>/dev/null || true

log "=== Backup Complete ==="

return 0
}

# Run main function
main
MAIN_EXIT_CODE=$?

# ============================================
# Self-Review (V5.0.1)
# ============================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Non-AI cron (no OpenClaw API calls) → tokens=0
INPUT_TOKENS=0
OUTPUT_TOKENS=0

# Determine status
if [ $MAIN_EXIT_CODE -eq 0 ]; then
  STATUS="ok"
  WHAT_WENT_WRONG="없음"
  WHY="백업 성공"
  NEXT_ACTION="없음"
else
  STATUS="fail"
  WHAT_WENT_WRONG="백업 실패 (exit code: $MAIN_EXIT_CODE)"
  WHY="스크립트 에러"
  NEXT_ACTION="로그 확인: $LOG_FILE"
fi

# Log self-review
sr_log_review \
  "Daily Backup" \
  "$DURATION" \
  "$INPUT_TOKENS" \
  "$OUTPUT_TOKENS" \
  "$STATUS" \
  "$WHAT_WENT_WRONG" \
  "$WHY" \
  "$NEXT_ACTION"

exit $MAIN_EXIT_CODE
