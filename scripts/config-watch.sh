#!/usr/bin/env bash
# Config Watch - openclaw.json 변경 감지 시 자동 백업
# Usage: config-watch.sh (백그라운드 실행 권장)

set -euo pipefail

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
BACKUP_SCRIPT="$HOME/openclaw/scripts/config-backup.sh"
LAST_HASH=""

echo "👀 Watching $CONFIG_FILE for changes..."
echo "   Press Ctrl+C to stop"
echo ""

while true; do
  if [ -f "$CONFIG_FILE" ]; then
    CURRENT_HASH=$(shasum -a 256 "$CONFIG_FILE" | cut -d' ' -f1)
    
    if [ -n "$LAST_HASH" ] && [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Config changed detected!"
      "$BACKUP_SCRIPT" "auto-watch" || true
      echo ""
    fi
    
    LAST_HASH="$CURRENT_HASH"
  fi
  
  sleep 10
done
