#!/usr/bin/env bash
# Config Backup Script - 설정 변경 시 자동 백업
# Usage: config-backup.sh [label]

set -euo pipefail

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
BACKUP_DIR="$HOME/openclaw/config-history"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LABEL="${1:-auto}"

# Backup directory 없으면 생성
mkdir -p "$BACKUP_DIR"

# Config 파일 존재 확인
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

# Backup 생성
BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}-${LABEL}.json"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# 파일 크기 확인
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "✅ Config backup created: $BACKUP_FILE ($SIZE)"

# 30일 이상 된 백업 자동 삭제
find "$BACKUP_DIR" -name "*.json" -type f -mtime +30 -delete 2>/dev/null || true

# 최근 5개 백업 목록
echo ""
echo "📋 Recent backups:"
ls -lt "$BACKUP_DIR"/*.json 2>/dev/null | head -5 | awk '{print "  - " $9 " (" $6" "$7" "$8")"}'

exit 0
