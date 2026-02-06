#!/bin/bash
# OpenClaw Daily Backup Script
# 매일 새벽 3시에 실행

set -euo pipefail

BACKUP_DIR=~/openclaw/backups
DATE=$(date +%Y%m%d-%H%M)
BACKUP_NAME="backup-${DATE}-DAILY"
LOG_FILE=~/.openclaw/logs/backup.log

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

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
