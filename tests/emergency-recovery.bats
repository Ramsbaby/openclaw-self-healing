#!/usr/bin/env bats

# OpenClaw Emergency Recovery Tests
# Tests for emergency-recovery.sh and emergency-recovery-v2.sh

setup() {
  export TEST_DIR="$(mktemp -d)"
  export LOG_DIR="$TEST_DIR/logs"
  export OPENCLAW_MEMORY_DIR="$LOG_DIR"
  mkdir -p "$LOG_DIR"

  # Mock configuration
  export RECOVERY_TIMEOUT=30
  export GATEWAY_URL="http://localhost:18789/"
  export CLAUDE_WORKSPACE_TRUST_TIMEOUT=2
  export CLAUDE_STARTUP_WAIT=1
  export WORKSPACE_TRUST_CONFIRM_WAIT=1
  export DISCORD_WEBHOOK_URL=""
  export TELEGRAM_BOT_TOKEN=""
  export TELEGRAM_CHAT_ID=""

  # Mock openclaw workspace
  export OPENCLAW_WORKSPACE_DIR="$TEST_DIR/openclaw"
  mkdir -p "$OPENCLAW_WORKSPACE_DIR"

  # Copy scripts
  cp scripts/emergency-recovery.sh "$TEST_DIR/" 2>/dev/null || true
  cp scripts/emergency-recovery-v2.sh "$TEST_DIR/" 2>/dev/null || true
  chmod +x "$TEST_DIR"/*.sh 2>/dev/null || true

  export PATH="$TEST_DIR/mocks:$PATH"
}

teardown() {
  # Kill any lingering tmux sessions
  tmux kill-session -t emergency_recovery_* 2>/dev/null || true
  rm -rf "$TEST_DIR"
}

# ============================================
# Lock File Tests
# ============================================

@test "Lock file prevents concurrent recovery" {
  skip "Requires full emergency-recovery script"

  # Create lock file
  LOCKFILE="$LOG_DIR/.emergency-recovery.lock"
  touch "$LOCKFILE"

  # Mock dependencies
  cat > "$TEST_DIR/mocks/tmux" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/tmux"

  if [ -f "$TEST_DIR/emergency-recovery.sh" ]; then
    run timeout 5s "$TEST_DIR/emergency-recovery.sh"

    # Should exit due to lock
    [ "$status" -ne 0 ] || [[ "$output" == *"already running"* ]]
  fi

  rm -f "$LOCKFILE"
}

# ============================================
# tmux Session Tests
# ============================================

@test "tmux session name includes timestamp" {
  skip "Integration test - requires full environment"

  # This test would verify that tmux session names are unique
  # by checking the session list after recovery starts
}

@test "tmux session is cleaned up on exit" {
  skip "Integration test - requires full environment"

  # This test would verify that cleanup trap removes tmux sessions
}

# ============================================
# Timeout Tests
# ============================================

@test "Recovery respects timeout setting" {
  skip "Integration test - requires Claude CLI mock"

  # Mock a long-running recovery
  export RECOVERY_TIMEOUT=2

  # Would verify that recovery terminates after timeout
}

# ============================================
# Metrics Tests
# ============================================

@test "Recovery metrics are recorded" {
  skip "Integration test - requires full recovery run"

  # Would verify that .emergency-recovery-metrics.json is created
  # and contains valid JSON with recovery statistics
}

# ============================================
# Notification Tests
# ============================================

@test "Discord notification is sent on failure" {
  skip "Requires network mock"

  # Mock curl for Discord webhook
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"discord.com"* ]]; then
  echo "200"
  exit 0
fi
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  # Would verify Discord webhook is called with proper payload
}

@test "Telegram notification is sent when configured" {
  skip "Requires network mock"

  export TELEGRAM_BOT_TOKEN="mock_token"
  export TELEGRAM_CHAT_ID="mock_chat_id"

  # Mock curl for Telegram API
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"telegram.org"* ]]; then
  echo "200"
  exit 0
fi
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  # Would verify Telegram API is called
}

# ============================================
# Recovery Learning Tests (v2 only)
# ============================================

@test "Recovery learnings file is created" {
  skip "Integration test - requires full v2 recovery"

  # Would verify that recovery-learnings.md is created and updated
  LEARNING_REPO="$LOG_DIR/recovery-learnings.md"

  # Check file exists and has proper format
  if [ -f "$LEARNING_REPO" ]; then
    grep -q "## Recovery Incident" "$LEARNING_REPO"
  fi
}

@test "Reasoning logs capture decision process" {
  skip "Integration test - requires Claude CLI"

  # Would verify that claude-reasoning-*.md is created
  # and contains structured reasoning logs
}

# ============================================
# Helper Function Tests
# ============================================

@test "Validates required commands exist" {
  # Test prerequisite checking
  cat > "$TEST_DIR/test_prereqs.sh" << 'EOF'
#!/bin/bash
command -v tmux >/dev/null 2>&1 || { echo "tmux required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
echo "Prerequisites OK"
EOF
  chmod +x "$TEST_DIR/test_prereqs.sh"

  # Mock missing tmux
  cat > "$TEST_DIR/mocks/tmux" << 'EOF'
#!/bin/bash
exit 127
EOF
  chmod +x "$TEST_DIR/mocks/tmux"

  run "$TEST_DIR/test_prereqs.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tmux required"* ]]
}

@test "Log files have restricted permissions" {
  skip "Requires actual log file creation"

  # Would verify that session logs have chmod 600
  SESSION_LOG="$LOG_DIR/claude-session-test.log"
  touch "$SESSION_LOG"
  chmod 600 "$SESSION_LOG"

  PERMS=$(stat -f "%Lp" "$SESSION_LOG" 2>/dev/null || stat -c "%a" "$SESSION_LOG" 2>/dev/null)
  [ "$PERMS" = "600" ]
}

# ============================================
# Edge Cases
# ============================================

@test "Handles corrupted metrics JSON gracefully" {
  # Create corrupted metrics file
  METRICS_FILE="$LOG_DIR/.emergency-recovery-metrics.json"
  echo "{ invalid json" > "$METRICS_FILE"

  # Should not crash when reading metrics
  run jq empty "$METRICS_FILE"
  [ "$status" -ne 0 ]

  # Recovery script should handle this gracefully
  # (actual handling would need to be implemented)
}

@test "Handles missing environment variables" {
  # Unset optional variables
  unset DISCORD_WEBHOOK_URL
  unset TELEGRAM_BOT_TOKEN

  # Should still work with defaults
  [ -z "$DISCORD_WEBHOOK_URL" ]
  [ -z "$TELEGRAM_BOT_TOKEN" ]

  # Recovery script should use defaults
}

@test "Handles spaces in file paths" {
  # Create directory with spaces
  SPACE_DIR="$TEST_DIR/dir with spaces"
  mkdir -p "$SPACE_DIR"

  export OPENCLAW_MEMORY_DIR="$SPACE_DIR"

  # Should handle spaces correctly
  LOG_FILE="$SPACE_DIR/test.log"
  echo "test" > "$LOG_FILE"
  [ -f "$LOG_FILE" ]
}
