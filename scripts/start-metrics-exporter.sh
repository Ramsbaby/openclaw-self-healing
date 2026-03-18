#!/usr/bin/env bash
# scripts/start-metrics-exporter.sh — Lifecycle manager for prometheus-exporter.py
#
# Usage:
#   bash scripts/start-metrics-exporter.sh start    # start in background
#   bash scripts/start-metrics-exporter.sh stop     # stop
#   bash scripts/start-metrics-exporter.sh restart  # stop then start
#   bash scripts/start-metrics-exporter.sh status   # show status + test command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${OPENCLAW_METRICS_PORT:-9090}"
PID_FILE="/tmp/openclaw-metrics-exporter.pid"
LOG_DIR="${OPENCLAW_MEMORY_DIR:-$HOME/openclaw/memory}"
LOG_FILE="$LOG_DIR/metrics-exporter.log"

cmd="${1:-status}"

case "$cmd" in
  start)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Already running (PID $(cat "$PID_FILE")) — http://localhost:${PORT}/metrics"
      exit 0
    fi
    mkdir -p "$LOG_DIR"
    nohup python3 "$SCRIPT_DIR/prometheus-exporter.py" "$PORT" >> "$LOG_FILE" 2>&1 &
    EXPORTER_PID=$!
    echo "$EXPORTER_PID" > "$PID_FILE"
    sleep 0.5
    if kill -0 "$EXPORTER_PID" 2>/dev/null; then
      echo "Started (PID $EXPORTER_PID) — http://localhost:${PORT}/metrics"
      echo "  Test: curl http://localhost:${PORT}/metrics"
      echo "  Logs: $LOG_FILE"
    else
      echo "FAILED to start — check $LOG_FILE" >&2
      rm -f "$PID_FILE"
      exit 1
    fi
    ;;

  stop)
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      if kill "$PID" 2>/dev/null; then
        echo "Stopped (PID $PID)"
      else
        echo "Process $PID not found (stale PID file removed)"
      fi
      rm -f "$PID_FILE"
    else
      echo "Not running"
    fi
    ;;

  restart)
    bash "$0" stop 2>/dev/null || true
    sleep 1
    bash "$0" start
    ;;

  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      PID=$(cat "$PID_FILE")
      echo "Running (PID $PID) — http://localhost:${PORT}/metrics"
      echo ""
      echo "  # Quick check:"
      echo "  curl -s http://localhost:${PORT}/metrics | head -25"
      echo ""
      echo "  # Prometheus scrape config:"
      echo "  # - job_name: 'openclaw'"
      echo "  #   static_configs:"
      echo "  #     - targets: ['localhost:${PORT}']"
    else
      echo "Not running"
      echo "  Start with: bash scripts/start-metrics-exporter.sh start"
    fi
    ;;

  *)
    echo "Usage: $0 {start|stop|restart|status}" >&2
    exit 1
    ;;
esac
