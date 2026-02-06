#!/bin/bash
set -euo pipefail

# Self-Healing System Test Suite
# Tests all 4 levels of the self-healing system

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================
# Helper Functions
# ============================================

print_header() {
  echo -e "\n${YELLOW}========================================${NC}"
  echo -e "${YELLOW}$1${NC}"
  echo -e "${YELLOW}========================================${NC}\n"
}

pass() {
  echo -e "${GREEN}✅ PASS:${NC} $1"
  ((TESTS_PASSED++))
}

fail() {
  echo -e "${RED}❌ FAIL:${NC} $1"
  ((TESTS_FAILED++))
}

warn() {
  echo -e "${YELLOW}⚠️  WARN:${NC} $1"
}

info() {
  echo "$1"
}

check_gateway_running() {
  if pgrep -f "openclaw-gateway" > /dev/null; then
    return 0
  else
    return 1
  fi
}

check_gateway_http() {
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/ 2>/dev/null || echo "000")
  
  if [ "$http_code" = "200" ]; then
    return 0
  else
    return 1
  fi
}

# ============================================
# Test Cases
# ============================================

test_environment() {
  print_header "Test: Environment Setup"
  
  # Check .env file exists
  if [ -f "$HOME/.openclaw/.env" ] || [ -f "$HOME/openclaw/.env" ]; then
    pass "Environment file exists"
  else
    warn "Environment file not found (optional)"
  fi
  
  # Check scripts exist
  if [ -f "$HOME/openclaw/scripts/gateway-healthcheck.sh" ]; then
    pass "gateway-healthcheck.sh exists"
  else
    fail "gateway-healthcheck.sh not found"
  fi
  
  if [ -f "$HOME/openclaw/scripts/emergency-recovery.sh" ]; then
    pass "emergency-recovery.sh exists"
  else
    fail "emergency-recovery.sh not found"
  fi
  
  if [ -f "$HOME/openclaw/scripts/emergency-recovery-monitor.sh" ]; then
    pass "emergency-recovery-monitor.sh exists"
  else
    fail "emergency-recovery-monitor.sh not found"
  fi
  
  # Check scripts are executable
  if [ -x "$HOME/openclaw/scripts/gateway-healthcheck.sh" ]; then
    pass "gateway-healthcheck.sh is executable"
  else
    fail "gateway-healthcheck.sh is not executable (run: chmod +x)"
  fi
}

test_dependencies() {
  print_header "Test: Dependencies"
  
  # Check tmux
  if command -v tmux &> /dev/null; then
    pass "tmux is installed"
  else
    fail "tmux is not installed (run: brew install tmux)"
  fi
  
  # Check Claude CLI
  if command -v claude &> /dev/null; then
    pass "Claude CLI is installed"
  else
    warn "Claude CLI is not installed (Level 3 will fail)"
  fi
  
  # Check OpenClaw
  if command -v openclaw &> /dev/null; then
    pass "OpenClaw CLI is installed"
  else
    fail "OpenClaw CLI is not installed"
  fi
  
  # Check curl
  if command -v curl &> /dev/null; then
    pass "curl is installed"
  else
    fail "curl is not installed"
  fi
}

test_gateway_status() {
  print_header "Test: Gateway Status"
  
  # Check process
  if check_gateway_running; then
    pass "Gateway process is running"
  else
    warn "Gateway process is not running"
  fi
  
  # Check HTTP
  if check_gateway_http; then
    pass "Gateway HTTP responds 200"
  else
    warn "Gateway HTTP does not respond 200"
  fi
  
  # Check port
  if lsof -i :18789 &> /dev/null; then
    pass "Port 18789 is in use (Gateway)"
  else
    warn "Port 18789 is not in use"
  fi
}

test_level1_watchdog() {
  print_header "Test: Level 1 - Watchdog"
  
  # Check LaunchAgent exists
  if [ -f "$HOME/Library/LaunchAgents/ai.openclaw.watchdog.plist" ]; then
    pass "Watchdog LaunchAgent plist exists"
  else
    warn "Watchdog LaunchAgent plist not found (OpenClaw may not auto-restart)"
  fi
  
  # Check LaunchAgent is loaded
  if launchctl list | grep -q "ai.openclaw.watchdog"; then
    pass "Watchdog LaunchAgent is loaded"
  else
    warn "Watchdog LaunchAgent is not loaded"
  fi
}

test_level2_healthcheck() {
  print_header "Test: Level 2 - Health Check"
  
  # Check LaunchAgent exists
  if [ -f "$HOME/Library/LaunchAgents/com.openclaw.healthcheck.plist" ]; then
    pass "Health Check LaunchAgent plist exists"
  else
    fail "Health Check LaunchAgent plist not found"
  fi
  
  # Check LaunchAgent is loaded
  if launchctl list | grep -q "com.openclaw.healthcheck"; then
    pass "Health Check LaunchAgent is loaded"
  else
    warn "Health Check LaunchAgent is not loaded (run: launchctl load)"
  fi
  
  # Check logs exist
  local today
  today=$(date +%Y-%m-%d)
  
  if [ -f "$HOME/openclaw/memory/healthcheck-$today.log" ]; then
    pass "Health Check log exists (ran today)"
  else
    warn "Health Check log not found (may not have run yet)"
  fi
  
  # Test health check script manually
  info "Testing Health Check script manually..."
  if bash "$HOME/openclaw/scripts/gateway-healthcheck.sh" >> /tmp/healthcheck-test.log 2>&1; then
    pass "Health Check script executed successfully"
  else
    fail "Health Check script failed (check: /tmp/healthcheck-test.log)"
  fi
}

test_level3_emergency_recovery() {
  print_header "Test: Level 3 - Emergency Recovery"
  
  # Check tmux is available
  if command -v tmux &> /dev/null; then
    pass "tmux is available for Level 3"
  else
    fail "tmux is not available (Level 3 will fail)"
  fi
  
  # Check Claude CLI is available
  if command -v claude &> /dev/null; then
    pass "Claude CLI is available for Level 3"
  else
    warn "Claude CLI is not available (Level 3 will fail)"
  fi
  
  # Test script syntax (don't actually run it)
  if bash -n "$HOME/openclaw/scripts/emergency-recovery.sh"; then
    pass "Emergency Recovery script syntax is valid"
  else
    fail "Emergency Recovery script has syntax errors"
  fi
}

test_level4_monitor() {
  print_header "Test: Level 4 - Emergency Monitor"
  
  # Test script syntax
  if bash -n "$HOME/openclaw/scripts/emergency-recovery-monitor.sh"; then
    pass "Emergency Monitor script syntax is valid"
  else
    fail "Emergency Monitor script has syntax errors"
  fi
  
  # Check cron job exists
  if openclaw cron list 2>/dev/null | grep -q "Emergency Recovery"; then
    pass "Emergency Monitor cron job exists"
  else
    warn "Emergency Monitor cron job not found (alerts disabled)"
  fi
}

test_metrics() {
  print_header "Test: Metrics Collection"
  
  # Check metrics files exist
  if [ -f "$HOME/openclaw/memory/.healthcheck-metrics.json" ]; then
    pass "Health Check metrics file exists"
    
    # Show last 3 entries
    info "Last 3 metrics:"
    tail -3 "$HOME/openclaw/memory/.healthcheck-metrics.json" 2>/dev/null || true
  else
    warn "Health Check metrics file not found (will be created on first run)"
  fi
  
  if [ -f "$HOME/openclaw/memory/.emergency-recovery-metrics.json" ]; then
    pass "Emergency Recovery metrics file exists"
  else
    warn "Emergency Recovery metrics file not found (will be created on first run)"
  fi
}

test_log_rotation() {
  print_header "Test: Log Rotation"
  
  # Count log files
  local healthcheck_logs
  healthcheck_logs=$(find "$HOME/openclaw/memory" -name "healthcheck-*.log" 2>/dev/null | wc -l)
  
  info "Health Check log files: $healthcheck_logs"
  
  if [ "$healthcheck_logs" -gt 20 ]; then
    warn "Many Health Check logs ($healthcheck_logs files). Log rotation may not be working."
  else
    pass "Health Check log count is reasonable ($healthcheck_logs files)"
  fi
  
  local recovery_logs
  recovery_logs=$(find "$HOME/openclaw/memory" -name "emergency-recovery-*.log" 2>/dev/null | wc -l)
  
  info "Emergency Recovery log files: $recovery_logs"
  
  if [ "$recovery_logs" -gt 10 ]; then
    warn "Many Emergency Recovery logs ($recovery_logs files). Log rotation may not be working."
  else
    pass "Emergency Recovery log count is reasonable ($recovery_logs files)"
  fi
}

# ============================================
# Main
# ============================================

main() {
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║  Self-Healing System Test Suite       ║"
  echo "╚════════════════════════════════════════╝"
  echo ""
  
  # Run all tests
  test_environment
  test_dependencies
  test_gateway_status
  test_level1_watchdog
  test_level2_healthcheck
  test_level3_emergency_recovery
  test_level4_monitor
  test_metrics
  test_log_rotation
  
  # Summary
  print_header "Test Summary"
  
  local total_tests=$((TESTS_PASSED + TESTS_FAILED))
  
  echo -e "Total tests: $total_tests"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  echo ""
  
  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    echo ""
    exit 0
  else
    echo -e "${RED}❌ Some tests failed. Please fix the issues above.${NC}"
    echo ""
    exit 1
  fi
}

# Run main
main
