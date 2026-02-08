#!/usr/bin/env bash
# Config Rollback Script - 이전 설정으로 복구
# Usage: config-rollback.sh [backup-file]
#        config-rollback.sh (interactive mode - 최근 5개 선택)

set -euo pipefail

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
BACKUP_DIR="$HOME/openclaw/config-history"

# Interactive mode
if [ $# -eq 0 ]; then
  echo "📋 Recent config backups:"
  echo ""
  
  # 최근 10개 백업 목록
  mapfile -t BACKUPS < <(ls -t "$BACKUP_DIR"/*.json 2>/dev/null | head -10)
  
  if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "❌ No backup files found in $BACKUP_DIR"
    exit 1
  fi
  
  # 번호 매겨서 출력
  for i in "${!BACKUPS[@]}"; do
    FILENAME=$(basename "${BACKUPS[$i]}")
    SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
    MTIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "${BACKUPS[$i]}")
    echo "  $((i+1)). $FILENAME ($SIZE, $MTIME)"
  done
  
  echo ""
  read -p "Select backup number (1-${#BACKUPS[@]}), or 0 to cancel: " CHOICE
  
  if [ "$CHOICE" -eq 0 ] 2>/dev/null; then
    echo "Cancelled."
    exit 0
  fi
  
  if [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#BACKUPS[@]} ] 2>/dev/null; then
    echo "❌ Invalid choice"
    exit 1
  fi
  
  BACKUP_FILE="${BACKUPS[$((CHOICE-1))]}"
else
  BACKUP_FILE="$1"
fi

# Backup 파일 존재 확인
if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Backup file not found: $BACKUP_FILE"
  exit 1
fi

# 현재 config를 emergency 백업
EMERGENCY_BACKUP="$BACKUP_DIR/emergency-$(date +%Y%m%d-%H%M%S).json"
cp "$CONFIG_FILE" "$EMERGENCY_BACKUP"
echo "🔒 Emergency backup created: $EMERGENCY_BACKUP"

# Rollback 실행
cp "$BACKUP_FILE" "$CONFIG_FILE"
echo "✅ Config restored from: $(basename "$BACKUP_FILE")"
echo ""
echo "⚠️  Gateway restart required: openclaw gateway restart"

exit 0
