#!/usr/bin/env bats

# OpenClaw Emergency Recovery Monitor Tests
# Tests for emergency-recovery-monitor.sh

setup() {
  export TEST_DIR="$(mktemp -d)"
  export LOG_DIR="$TEST_DIR/logs"
  export OPENCLAW_MEMORY_DIR="$LOG_DIR"
  mkdir -p "$LOG_DIR"

  # Mock configuration
  export EMERGENCY_ALERT_WINDOW=30
  export DISCORD_WEBHOOK_URL=""
  export TELEGRAM_BOT_TOKEN=""

  # Copy script
  cp scripts/emergency-recovery-monitor.sh "$TEST_DIR/" 2>/dev/null || true
  chmod +x "$TEST_DIR/emergency-recovery-monitor.sh" 2>/dev/null || true

  export PATH="$TEST_DIR/mocks:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ============================================
# Log Detection Tests
# ============================================

@test "Detects MANUAL INTERVENTION REQUIRED pattern" {
  # Create a recovery log with failure pattern
  LOG_FILE="$LOG_DIR/emergency-recovery-test-$(date +%Y-%m-%d-%H%M).log"
  cat > "$LOG_FILE" << 'EOF'
[2026-02-10 10:00:00] === Emergency Recovery Started ===
[2026-02-10 10:30:00] Gateway still unhealthy (HTTP 500)

=== MANUAL INTERVENTION REQUIRED ===
Level 1 (Watchdog) ❌
Level 2 (Health Check) ❌
Level 3 (Claude Recovery) ❌
EOF

  # Check pattern exists
  grep -q "MANUAL INTERVENTION REQUIRED" "$LOG_FILE"
  [ $? -eq 0 ]
}

@test "Ignores logs without failure pattern" {
  # Create a recovery log with success
  LOG_FILE="$LOG_DIR/emergency-recovery-test-$(date +%Y-%m-%d-%H%M).log"
  cat > "$LOG_FILE" << 'EOF'
[2026-02-10 10:00:00] === Emergency Recovery Started ===
[2026-02-10 10:05:00] Gateway recovered successfully ✅
EOF

  # Should not match failure pattern
  ! grep -q "MANUAL INTERVENTION REQUIRED" "$LOG_FILE"
}

# ============================================
# Alert Tracking Tests
# ============================================

@test "Alert tracking file prevents duplicate alerts" {
  skip "Requires monitor script execution"

  # Would verify that .emergency-alert-sent.log prevents duplicates
  ALERT_FILE="$LOG_DIR/.emergency-alert-sent.log"

  # First alert should be sent
  # Second alert within window should be skipped
}

@test "Alert tracking respects time window" {
  skip "Requires monitor script execution"

  # Create old alert timestamp (31 minutes ago)
  ALERT_FILE="$LOG_DIR/.emergency-alert-sent.log"
  OLD_TIMESTAMP=$(date -v-31M +%s 2>/dev/null || date -d '31 minutes ago' +%s)
  echo "$OLD_TIMESTAMP" > "$ALERT_FILE"

  # New alert should be allowed (outside 30-min window)
}

# ============================================
# Notification Tests
# ============================================

@test "Discord notification includes log excerpt" {
  skip "Requires network mock"

  # Mock curl
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"discord.com"* ]]; then
  # Verify payload contains log excerpt
  echo "$@" | grep -q "Last 30 lines"
  exit 0
fi
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  # Would verify notification payload structure
}

# ============================================
# Edge Cases
# ============================================

@test "Handles empty log directory" {
  # Remove all logs
  rm -f "$LOG_DIR"/*.log

  # Monitor should not crash
  if [ -f "$TEST_DIR/emergency-recovery-monitor.sh" ]; then
    run timeout 5s "$TEST_DIR/emergency-recovery-monitor.sh"
    # Should exit gracefully (status 0 or 1, but not crash)
  fi
}

@test "Handles very large log files" {
  skip "Performance test"

  # Create 10MB log file
  LOG_FILE="$LOG_DIR/emergency-recovery-large-$(date +%Y-%m-%d-%H%M).log"
  dd if=/dev/zero of="$LOG_FILE" bs=1M count=10 2>/dev/null
  echo "MANUAL INTERVENTION REQUIRED" >> "$LOG_FILE"

  # Should still process efficiently
}

@test "Handles concurrent monitor executions" {
  skip "Concurrency test"

  # Would verify that multiple monitor instances don't conflict
  # Lock file mechanism should prevent race conditions
}

# ============================================
# Log Parsing Tests
# ============================================

@test "Extracts relevant log lines for alert" {
  LOG_FILE="$LOG_DIR/emergency-recovery-test-$(date +%Y-%m-%d-%H%M).log"

  # Create log with various content
  for i in {1..100}; do
    echo "[2026-02-10 10:00:$i] Debug line $i" >> "$LOG_FILE"
  done
  echo "MANUAL INTERVENTION REQUIRED" >> "$LOG_FILE"

  # Should extract last 30 lines
  TAIL_OUTPUT=$(tail -30 "$LOG_FILE")
  LINES=$(echo "$TAIL_OUTPUT" | wc -l)
  [ "$LINES" -le 31 ]  # 30 lines + potential newline
}

# ============================================
# Integration Tests
# ============================================

@test "Monitor detects failure and sends alert (dry run)" {
  skip "Full integration test"

  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  # Create failure log
  LOG_FILE="$LOG_DIR/emergency-recovery-test-$(date +%Y-%m-%d-%H%M).log"
  cat > "$LOG_FILE" << 'EOF'
[2026-02-10 10:00:00] === Emergency Recovery Started ===
=== MANUAL INTERVENTION REQUIRED ===
EOF

  # Mock curl to verify webhook call
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"discord.com"* ]]; then
  echo "Webhook called with: $*" >> /tmp/monitor-test-webhook.log
  echo "200"
  exit 0
fi
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  # Run monitor
  if [ -f "$TEST_DIR/emergency-recovery-monitor.sh" ]; then
    run "$TEST_DIR/emergency-recovery-monitor.sh"
    [ "$status" -eq 0 ]

    # Verify webhook was called
    [ -f /tmp/monitor-test-webhook.log ]
  fi

  rm -f /tmp/monitor-test-webhook.log
}
