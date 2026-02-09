#!/bin/bash
# 로그 로테이션 (macOS 호환 버전)
# 매일 04:00 실행 (야간 종합 점검 전)

set -euo pipefail

LOG_DIR=~/.openclaw/logs
ARCHIVE_DIR=$LOG_DIR/archive
mkdir -p "$ARCHIVE_DIR"

DATE=$(date +%Y%m%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Log Rotation: $DATE ==="

rotate_log() {
  local logfile="$1"
  local threshold="$2"  # KB
  local name=$(basename "$logfile" .log)
  
  if [ ! -f "$logfile" ]; then
    return
  fi
  
  # macOS: stat -f%z, Linux: stat -c%s
  local size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null)
  local size_kb=$((size / 1024))
  
  if [ "$size_kb" -ge "$threshold" ]; then
    # copytruncate 방식 (로그 유실 방지)
    cp "$logfile" "$ARCHIVE_DIR/${name}.${TIMESTAMP}.log"
    cat /dev/null > "$logfile"
    gzip -f "$ARCHIVE_DIR/${name}.${TIMESTAMP}.log"
    echo "✅ ${name}.log rotated (${size_kb}KB)"
    return 0
  else
    echo "⏭️  ${name}.log OK (${size_kb}KB < ${threshold}KB)"
    return 1
  fi
}

# 로테이션 실행 (임계치: KB)
rotate_log "$LOG_DIR/gateway.log" 500 || true         # 500KB
rotate_log "$LOG_DIR/gateway.err.log" 100 || true     # 100KB
rotate_log "$LOG_DIR/watchdog.log" 300 || true        # 300KB
rotate_log "$LOG_DIR/response-guard.log" 200 || true  # 200KB
rotate_log "$LOG_DIR/context-monitor.log" 200 || true # 200KB

# 30일 이상 된 아카이브 삭제
OLD_COUNT=$(find "$ARCHIVE_DIR" -name "*.gz" -mtime +30 2>/dev/null | wc -l | tr -d ' ')
find "$ARCHIVE_DIR" -name "*.gz" -mtime +30 -delete 2>/dev/null
echo "🗑️  Old archives: $OLD_COUNT deleted"

# 현재 상태
echo ""
echo "=== Current Logs ==="
du -sh "$LOG_DIR" 2>/dev/null
ls -lh "$LOG_DIR"/*.log 2>/dev/null | awk '{printf "%-40s %s\n", $9, $5}' | tail -5
