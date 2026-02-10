#!/bin/bash
set -euo pipefail

# OpenClaw Self-Healing Doctor
# Diagnostic tool for troubleshooting self-healing system

# ============================================
# Configuration
# ============================================
GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789/}"
LOG_DIR="${OPENCLAW_MEMORY_DIR:-$HOME/openclaw/memory}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================
# Diagnostic Functions
# ============================================

check_prerequisites() {
  echo -e "${BOLD}Checking Prerequisites...${RESET}"

  local errors=0

  # Check tmux
  if command -v tmux &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} tmux installed ($(tmux -V))"
  else
    echo -e "  ${RED}✗${RESET} tmux not found"
    errors=$((errors + 1))
  fi

  # Check jq
  if command -v jq &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} jq installed ($(jq --version))"
  else
    echo -e "  ${RED}✗${RESET} jq not found"
    errors=$((errors + 1))
  fi

  # Check curl
  if command -v curl &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} curl installed ($(curl --version | head -1))"
  else
    echo -e "  ${RED}✗${RESET} curl not found"
    errors=$((errors + 1))
  fi

  # Check openclaw
  if command -v openclaw &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} openclaw CLI found"
  else
    echo -e "  ${YELLOW}!${RESET} openclaw CLI not in PATH"
  fi

  echo ""
  return $errors
}

check_services() {
  echo -e "${BOLD}Checking Services...${RESET}"

  local errors=0

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS LaunchAgent
    local plist="$HOME/Library/LaunchAgents/com.openclaw.healthcheck.plist"
    if [ -f "$plist" ]; then
      echo -e "  ${GREEN}✓${RESET} Health check LaunchAgent installed"

      if launchctl list | grep -q "openclaw.healthcheck"; then
        echo -e "  ${GREEN}✓${RESET} Health check service loaded"
      else
        echo -e "  ${RED}✗${RESET} Health check service not loaded"
        echo -e "    ${BLUE}Fix:${RESET} launchctl load \"$plist\""
        errors=$((errors + 1))
      fi
    else
      echo -e "  ${RED}✗${RESET} Health check LaunchAgent not found"
      errors=$((errors + 1))
    fi
  else
    # Linux systemd
    if systemctl --user list-unit-files | grep -q "openclaw-healthcheck.service"; then
      echo -e "  ${GREEN}✓${RESET} Health check systemd service installed"

      if systemctl --user is-active openclaw-healthcheck.service &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Health check service active"
      else
        echo -e "  ${RED}✗${RESET} Health check service inactive"
        echo -e "    ${BLUE}Fix:${RESET} systemctl --user start openclaw-healthcheck.service"
        errors=$((errors + 1))
      fi
    else
      echo -e "  ${RED}✗${RESET} Health check systemd service not found"
      errors=$((errors + 1))
    fi
  fi

  # Check cron for monitor
  if crontab -l 2>/dev/null | grep -q "emergency-recovery-monitor.sh"; then
    echo -e "  ${GREEN}✓${RESET} Emergency recovery monitor in crontab"
  else
    echo -e "  ${YELLOW}!${RESET} Emergency recovery monitor not scheduled"
    echo -e "    ${BLUE}Tip:${RESET} Add to crontab for Level 4 alerts"
  fi

  echo ""
  return $errors
}

check_gateway() {
  echo -e "${BOLD}Checking Gateway...${RESET}"

  local errors=0

  # Check if process is running
  if pgrep -f "openclaw-gateway" &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} Gateway process running"
  else
    echo -e "  ${RED}✗${RESET} Gateway process not found"
    errors=$((errors + 1))
  fi

  # Check HTTP endpoint
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$GATEWAY_URL" 2>/dev/null || echo "000")

  if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓${RESET} Gateway responding (HTTP 200)"
  else
    echo -e "  ${RED}✗${RESET} Gateway not responding (HTTP $http_code)"
    errors=$((errors + 1))
  fi

  echo ""
  return $errors
}

check_logs() {
  echo -e "${BOLD}Checking Logs...${RESET}"

  local errors=0

  if [ -d "$LOG_DIR" ]; then
    echo -e "  ${GREEN}✓${RESET} Log directory exists: $LOG_DIR"

    # Check recent health check logs
    local today_log="$LOG_DIR/healthcheck-$(date +%Y-%m-%d).log"
    if [ -f "$today_log" ]; then
      echo -e "  ${GREEN}✓${RESET} Today's health check log exists"

      local last_check
      last_check=$(tail -1 "$today_log" 2>/dev/null | grep -o '\[.*\]' | tr -d '[]' || echo "unknown")
      echo -e "    Last check: $last_check"
    else
      echo -e "  ${YELLOW}!${RESET} No health check log for today"
    fi

    # Check for recent failures
    local failures
    failures=$(find "$LOG_DIR" -name "emergency-recovery-*.log" -mtime -1 -type f 2>/dev/null | wc -l)
    if [ "$failures" -gt 0 ]; then
      echo -e "  ${YELLOW}!${RESET} $failures emergency recovery attempts in last 24h"
    else
      echo -e "  ${GREEN}✓${RESET} No recent recovery attempts"
    fi
  else
    echo -e "  ${RED}✗${RESET} Log directory not found: $LOG_DIR"
    errors=$((errors + 1))
  fi

  echo ""
  return $errors
}

check_configuration() {
  echo -e "${BOLD}Checking Configuration...${RESET}"

  local errors=0

  # Check .env file
  local env_file="$HOME/.openclaw/.env"
  if [ -f "$env_file" ]; then
    echo -e "  ${GREEN}✓${RESET} Environment file exists"

    # Check Discord webhook
    if grep -q "DISCORD_WEBHOOK_URL=" "$env_file"; then
      local webhook
      webhook=$(grep "DISCORD_WEBHOOK_URL=" "$env_file" | cut -d= -f2 | tr -d '"' | tr -d "'")
      if [ -n "$webhook" ] && [ "$webhook" != "your_webhook_url_here" ]; then
        echo -e "  ${GREEN}✓${RESET} Discord webhook configured"
      else
        echo -e "  ${YELLOW}!${RESET} Discord webhook not set (alerts disabled)"
      fi
    fi
  else
    echo -e "  ${YELLOW}!${RESET} Environment file not found (using defaults)"
  fi

  echo ""
  return $errors
}

# ============================================
# Fix Functions
# ============================================

auto_fix() {
  echo -e "${BOLD}${BLUE}Attempting Auto-Fix...${RESET}"
  echo ""

  local fixed=0

  # Fix: Reload LaunchAgent if not loaded
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local plist="$HOME/Library/LaunchAgents/com.openclaw.healthcheck.plist"
    if [ -f "$plist" ] && ! launchctl list | grep -q "openclaw.healthcheck"; then
      echo -e "  ${BLUE}→${RESET} Loading health check service..."
      if launchctl load "$plist" 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Service loaded"
        fixed=$((fixed + 1))
      else
        echo -e "  ${RED}✗${RESET} Failed to load service"
      fi
    fi
  fi

  # Fix: Start systemd service if inactive
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if systemctl --user list-unit-files | grep -q "openclaw-healthcheck.service"; then
      if ! systemctl --user is-active openclaw-healthcheck.service &>/dev/null; then
        echo -e "  ${BLUE}→${RESET} Starting health check service..."
        if systemctl --user start openclaw-healthcheck.service 2>/dev/null; then
          echo -e "  ${GREEN}✓${RESET} Service started"
          fixed=$((fixed + 1))
        else
          echo -e "  ${RED}✗${RESET} Failed to start service"
        fi
      fi
    fi
  fi

  # Fix: Create log directory if missing
  if [ ! -d "$LOG_DIR" ]; then
    echo -e "  ${BLUE}→${RESET} Creating log directory..."
    if mkdir -p "$LOG_DIR" 2>/dev/null; then
      echo -e "  ${GREEN}✓${RESET} Log directory created"
      fixed=$((fixed + 1))
    else
      echo -e "  ${RED}✗${RESET} Failed to create log directory"
    fi
  fi

  echo ""
  if [ $fixed -gt 0 ]; then
    echo -e "${GREEN}Fixed $fixed issue(s)${RESET}"
  else
    echo -e "${YELLOW}No issues to auto-fix${RESET}"
  fi
  echo ""
}

# ============================================
# Main
# ============================================

main() {
  echo ""
  echo -e "${BOLD}${BLUE}OpenClaw Self-Healing Doctor${RESET}"
  echo ""

  local total_errors=0

  check_prerequisites
  total_errors=$((total_errors + $?))

  check_services
  total_errors=$((total_errors + $?))

  check_gateway
  total_errors=$((total_errors + $?))

  check_logs
  total_errors=$((total_errors + $?))

  check_configuration
  total_errors=$((total_errors + $?))

  # Summary
  if [ $total_errors -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✓ All checks passed!${RESET}"
  else
    echo -e "${BOLD}${RED}✗ Found $total_errors issue(s)${RESET}"
    echo ""
    echo -e "${BLUE}Tip:${RESET} Run with --fix to attempt automatic repairs"
  fi

  echo ""
}

case "${1:-}" in
  --fix)
    main
    auto_fix
    ;;
  --help|-h)
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OpenClaw Self-Healing Diagnostic Tool"
    echo ""
    echo "Options:"
    echo "  --fix             Attempt to fix issues automatically"
    echo "  --help, -h        Show this help message"
    echo ""
    exit 0
    ;;
  *)
    main
    ;;
esac
