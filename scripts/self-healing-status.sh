#!/bin/bash
set -euo pipefail

# OpenClaw Self-Healing Status Dashboard
# Displays current status, metrics, and recovery history

# ============================================
# Configuration
# ============================================
GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789/}"
LOG_DIR="${OPENCLAW_MEMORY_DIR:-$HOME/openclaw/memory}"
METRICS_FILE="$LOG_DIR/.healthcheck-metrics.json"
RECOVERY_METRICS_FILE="$LOG_DIR/.emergency-recovery-metrics.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Unicode box drawing
TOP_LEFT="┌"
TOP_RIGHT="┐"
BOTTOM_LEFT="└"
BOTTOM_RIGHT="┘"
HORIZONTAL="─"
VERTICAL="│"

# ============================================
# Helper Functions
# ============================================

print_header() {
  local title="$1"
  local width=60
  local padding=$(( (width - ${#title} - 2) / 2 ))

  echo -e "${BOLD}${CYAN}${TOP_LEFT}${HORIZONTAL}${title}${HORIZONTAL}$(printf '%*s' $((width - ${#title} - 2 - padding)) '' | tr ' ' "${HORIZONTAL}")${TOP_RIGHT}${RESET}"
}

print_footer() {
  local width=60
  echo -e "${CYAN}${BOTTOM_LEFT}$(printf '%*s' $((width - 2)) '' | tr ' ' "${HORIZONTAL}")${BOTTOM_RIGHT}${RESET}"
}

print_line() {
  local label="$1"
  local value="$2"
  local color="${3:-$RESET}"

  printf "${CYAN}${VERTICAL}${RESET} %-25s ${color}%s${RESET}\n" "$label" "$value"
}

check_gateway_health() {
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$GATEWAY_URL" 2>/dev/null || echo "000")

  if [ "$http_code" = "200" ]; then
    echo "✅ Healthy"
    return 0
  else
    echo "❌ Unhealthy (HTTP $http_code)"
    return 1
  fi
}

get_uptime() {
  # Try to get Gateway uptime from process
  local pid
  pid=$(pgrep -f "openclaw-gateway" 2>/dev/null | head -1 || echo "")

  if [ -n "$pid" ]; then
    # macOS vs Linux ps command
    if [[ "$OSTYPE" == "darwin"* ]]; then
      local etime
      etime=$(ps -p "$pid" -o etime= 2>/dev/null | xargs || echo "unknown")
      echo "$etime"
    else
      local etime
      etime=$(ps -p "$pid" -o etime= 2>/dev/null | xargs || echo "unknown")
      echo "$etime"
    fi
  else
    echo "not running"
  fi
}

calculate_success_rate() {
  if [ ! -f "$METRICS_FILE" ]; then
    echo "N/A"
    return
  fi

  # Count successes and failures
  local total
  local successes
  total=$(jq -s 'length' "$METRICS_FILE" 2>/dev/null || echo "0")
  successes=$(jq -s '[.[] | select(.status == "success")] | length' "$METRICS_FILE" 2>/dev/null || echo "0")

  if [ "$total" -eq 0 ]; then
    echo "N/A (no data)"
  else
    local rate
    rate=$(echo "scale=1; $successes * 100 / $total" | bc 2>/dev/null || echo "0")
    echo "${rate}% ($successes/$total)"
  fi
}

calculate_mttr() {
  if [ ! -f "$RECOVERY_METRICS_FILE" ]; then
    echo "N/A"
    return
  fi

  # Calculate average recovery time
  local avg_time
  avg_time=$(jq -s '[.[] | select(.recovery_duration != null) | .recovery_duration] | add / length' "$RECOVERY_METRICS_FILE" 2>/dev/null || echo "0")

  if [ "$avg_time" = "0" ] || [ "$avg_time" = "null" ]; then
    echo "N/A"
  else
    echo "${avg_time}s"
  fi
}

get_recent_recoveries() {
  local limit="${1:-5}"

  # Find recent emergency recovery logs
  local logs
  logs=$(find "$LOG_DIR" -name "emergency-recovery-*.log" -type f 2>/dev/null | sort -r | head -"$limit")

  if [ -z "$logs" ]; then
    echo "  ${YELLOW}No recovery history found${RESET}"
    return
  fi

  echo ""
  while IFS= read -r log_file; do
    # Extract timestamp from filename
    local timestamp
    timestamp=$(basename "$log_file" | sed 's/emergency-recovery-//;s/.log$//')

    # Determine recovery level and status
    local level="Unknown"
    local status="❓"
    local duration="N/A"
    local reason=""

    if grep -q "Level 3.*SUCCESS" "$log_file" 2>/dev/null; then
      level="Level 3"
      status="✅"
    elif grep -q "Level 2.*SUCCESS" "$log_file" 2>/dev/null; then
      level="Level 2"
      status="✅"
    elif grep -q "Level 1.*SUCCESS" "$log_file" 2>/dev/null; then
      level="Level 1"
      status="✅"
    elif grep -q "MANUAL INTERVENTION REQUIRED" "$log_file" 2>/dev/null; then
      level="Level 4"
      status="❌"
    fi

    # Extract duration if available
    if grep -q "Recovery took" "$log_file" 2>/dev/null; then
      duration=$(grep "Recovery took" "$log_file" | head -1 | sed 's/.*Recovery took //;s/ .*//')
    fi

    # Extract reason (last log line before recovery)
    reason=$(grep -i "error\|fail\|crash\|unhealthy" "$log_file" 2>/dev/null | tail -1 | cut -c1-30 || echo "")

    # Format timestamp for display
    local display_time
    display_time=$(echo "$timestamp" | sed 's/-/ /g;s/\([0-9]\{2\}\)\([0-9]\{2\}\)$/\1:\2/')

    printf "  ${CYAN}%s${RESET}  %-8s ${status} %-5s  %s\n" \
      "$display_time" "$level" "$duration" "${reason:-Unknown}"
  done <<< "$logs"
}

get_next_check_time() {
  # Check LaunchAgent schedule (macOS)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local plist="$HOME/Library/LaunchAgents/com.openclaw.healthcheck.plist"
    if [ -f "$plist" ]; then
      local interval
      interval=$(plutil -extract StartInterval raw "$plist" 2>/dev/null || echo "300")

      # Get last run time
      local last_run
      last_run=$(find "$LOG_DIR" -name "healthcheck-*.log" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -n | tail -1 || echo "0")

      if [ "$last_run" != "0" ]; then
        local next_run=$((last_run + interval))
        local now
        now=$(date +%s)
        local remaining=$((next_run - now))

        if [ $remaining -gt 0 ]; then
          local minutes=$((remaining / 60))
          echo "in ${minutes}m"
        else
          echo "now"
        fi
      else
        echo "unknown"
      fi
    else
      echo "not scheduled"
    fi
  else
    # Linux systemd
    local service="openclaw-healthcheck.service"
    if systemctl --user is-active "$service" &>/dev/null; then
      local next_run
      next_run=$(systemctl --user show "$service" -p NextElapseUSecRealtime --value 2>/dev/null || echo "")
      if [ -n "$next_run" ] && [ "$next_run" != "n/a" ]; then
        echo "$(date -d "$next_run" '+%H:%M' 2>/dev/null || echo 'unknown')"
      else
        echo "unknown"
      fi
    else
      echo "not scheduled"
    fi
  fi
}

get_system_load() {
  # Get 1-minute load average
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sysctl -n vm.loadavg | awk '{print $2}'
  else
    uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs
  fi
}

# ============================================
# Main Dashboard
# ============================================

main() {
  clear
  echo ""

  # Header
  print_header " OpenClaw Self-Healing Status "

  # Gateway Health
  local health
  health=$(check_gateway_health)
  local health_color
  if [[ "$health" == *"✅"* ]]; then
    health_color="$GREEN"
  else
    health_color="$RED"
  fi
  print_line "Gateway Health:" "$health" "$health_color"

  # Uptime
  local uptime
  uptime=$(get_uptime)
  print_line "Gateway Uptime:" "$uptime" "$RESET"

  # Success Rate
  local success_rate
  success_rate=$(calculate_success_rate)
  local rate_color
  if [[ "$success_rate" == 100* ]] || [[ "$success_rate" == 9[5-9]* ]]; then
    rate_color="$GREEN"
  elif [[ "$success_rate" == N/A* ]]; then
    rate_color="$YELLOW"
  else
    rate_color="$YELLOW"
  fi
  print_line "Recovery Success Rate:" "$success_rate" "$rate_color"

  # MTTR
  local mttr
  mttr=$(calculate_mttr)
  print_line "MTTR (avg):" "$mttr" "$RESET"

  # System Load
  local load
  load=$(get_system_load)
  print_line "System Load:" "$load" "$RESET"

  # Next Check
  local next_check
  next_check=$(get_next_check_time)
  print_line "Next Health Check:" "$next_check" "$CYAN"

  print_footer

  # Recent Recoveries
  echo ""
  echo -e "${BOLD}${MAGENTA}Recent Recovery History:${RESET}"
  get_recent_recoveries 5

  echo ""
  echo -e "${BOLD}Monitoring:${RESET}"
  echo -e "  ${CYAN}Logs:${RESET}       $LOG_DIR"
  echo -e "  ${CYAN}Metrics:${RESET}    $METRICS_FILE"

  # Quick Actions
  echo ""
  echo -e "${BOLD}Quick Actions:${RESET}"
  echo -e "  ${GREEN}openclaw status${RESET}              Check Gateway status"
  echo -e "  ${GREEN}tail -f $LOG_DIR/healthcheck-\$(date +%Y-%m-%d).log${RESET}"
  echo -e "  ${GREEN}launchctl list | grep openclaw${RESET}   Check services (macOS)"

  echo ""
}

# ============================================
# Options
# ============================================

case "${1:-}" in
  --help|-h)
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OpenClaw Self-Healing Status Dashboard"
    echo ""
    echo "Options:"
    echo "  --help, -h        Show this help message"
    echo "  --json            Output as JSON"
    echo "  --watch           Refresh every 5 seconds"
    echo ""
    echo "Environment Variables:"
    echo "  OPENCLAW_GATEWAY_URL    Gateway URL (default: http://localhost:18789/)"
    echo "  OPENCLAW_MEMORY_DIR     Log directory (default: ~/openclaw/memory)"
    echo ""
    exit 0
    ;;
  --json)
    # JSON output for programmatic access
    echo "{"
    echo "  \"gateway_health\": \"$(check_gateway_health | sed 's/[^a-zA-Z0-9 ]//g')\","
    echo "  \"uptime\": \"$(get_uptime)\","
    echo "  \"success_rate\": \"$(calculate_success_rate)\","
    echo "  \"mttr\": \"$(calculate_mttr)\","
    echo "  \"system_load\": \"$(get_system_load)\","
    echo "  \"next_check\": \"$(get_next_check_time)\""
    echo "}"
    exit 0
    ;;
  --watch)
    # Watch mode - refresh every 5 seconds
    while true; do
      main
      sleep 5
    done
    ;;
  *)
    main
    ;;
esac
