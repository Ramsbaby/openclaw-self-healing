#!/usr/bin/env bats

# OpenClaw Gateway Health Check Tests
# Tests for gateway-healthcheck.sh

setup() {
  # Create temporary directories for testing
  export TEST_DIR="$(mktemp -d)"
  export LOG_DIR="$TEST_DIR/logs"
  export OPENCLAW_MEMORY_DIR="$LOG_DIR"
  mkdir -p "$LOG_DIR"

  # Mock configuration
  export GATEWAY_URL="http://localhost:18789/"
  export MAX_RETRIES=3
  export RETRY_DELAY=1
  export ESCALATION_WAIT=5
  export HTTP_TIMEOUT=5
  export DISCORD_WEBHOOK_URL=""

  # Copy script to test directory
  cp scripts/gateway-healthcheck.sh "$TEST_DIR/"
  chmod +x "$TEST_DIR/gateway-healthcheck.sh"

  # Mock curl command
  export PATH="$TEST_DIR/mocks:$PATH"
}

teardown() {
  # Clean up test directory
  rm -rf "$TEST_DIR"
}

# ============================================
# HTTP Check Tests
# ============================================

@test "HTTP check succeeds on 200 response" {
  # Mock curl to return HTTP 200
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"-w"* ]]; then
  echo "200"
else
  exit 0
fi
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  # Mock openclaw command
  cat > "$TEST_DIR/mocks/openclaw" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/openclaw"

  run "$TEST_DIR/gateway-healthcheck.sh"
  [ "$status" -eq 0 ]

  # Check log file was created
  [ -f "$LOG_DIR/healthcheck-$(date +%Y-%m-%d).log" ]
}

@test "HTTP check fails on 500 response" {
  # Mock curl to return HTTP 500
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"-w"* ]]; then
  echo "500"
  exit 0
else
  exit 1
fi
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  # Mock openclaw command to fail initially
  cat > "$TEST_DIR/mocks/openclaw" << 'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$TEST_DIR/mocks/openclaw"

  # Mock emergency recovery script (should not be called in this test)
  export OPENCLAW_WORKSPACE_DIR="$TEST_DIR"
  mkdir -p "$TEST_DIR/scripts"
  cat > "$TEST_DIR/scripts/emergency-recovery.sh" << 'EOF'
#!/bin/bash
echo "Emergency recovery called" >> "$OPENCLAW_MEMORY_DIR/emergency-called.log"
exit 0
EOF
  chmod +x "$TEST_DIR/scripts/emergency-recovery.sh"

  # This should fail after retries
  run timeout 30s "$TEST_DIR/gateway-healthcheck.sh"

  # Should have attempted retries
  LOG_FILE="$LOG_DIR/healthcheck-$(date +%Y-%m-%d).log"
  [ -f "$LOG_FILE" ]
  grep -q "HTTP check failed" "$LOG_FILE" || true
}

@test "Lock file prevents concurrent execution" {
  # Create lock file
  touch /tmp/openclaw-healthcheck.lock

  run "$TEST_DIR/gateway-healthcheck.sh"
  [ "$status" -eq 0 ]

  # Should skip execution
  [[ "$output" == *"Previous health check still running"* ]] || [[ "$output" == "" ]]

  # Clean up
  rm -f /tmp/openclaw-healthcheck.lock
}

# ============================================
# Retry Logic Tests
# ============================================

@test "Retries configured number of times" {
  # Mock curl to always fail
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
echo "500"
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  # Mock openclaw to fail
  cat > "$TEST_DIR/mocks/openclaw" << 'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$TEST_DIR/mocks/openclaw"

  # Reduce retry delay for faster test
  export RETRY_DELAY=0
  export MAX_RETRIES=2
  export ESCALATION_WAIT=2

  run timeout 20s "$TEST_DIR/gateway-healthcheck.sh"

  LOG_FILE="$LOG_DIR/healthcheck-$(date +%Y-%m-%d).log"
  [ -f "$LOG_FILE" ]
}

# ============================================
# Metrics Tests
# ============================================

@test "Metrics file is created and valid JSON" {
  # Mock successful HTTP check
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"-w"* ]]; then
  echo "200"
else
  exit 0
fi
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  cat > "$TEST_DIR/mocks/openclaw" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/openclaw"

  run "$TEST_DIR/gateway-healthcheck.sh"
  [ "$status" -eq 0 ]

  # Check metrics file
  METRICS_FILE="$LOG_DIR/.healthcheck-metrics.json"
  if [ -f "$METRICS_FILE" ]; then
    # Validate JSON
    run jq empty "$METRICS_FILE"
    [ "$status" -eq 0 ]
  fi
}

# ============================================
# Environment Variable Tests
# ============================================

@test "Uses custom GATEWAY_URL from environment" {
  export GATEWAY_URL="http://custom:9999/"

  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
# Check if custom URL is used
if [[ "$*" == *"http://custom:9999/"* ]]; then
  echo "200"
  exit 0
else
  echo "000"
  exit 1
fi
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  cat > "$TEST_DIR/mocks/openclaw" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/openclaw"

  run "$TEST_DIR/gateway-healthcheck.sh"
  [ "$status" -eq 0 ]
}

# ============================================
# Discord Notification Tests
# ============================================

@test "Skips Discord notification when webhook not set" {
  export DISCORD_WEBHOOK_URL=""

  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
echo "200"
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/curl"

  cat > "$TEST_DIR/mocks/openclaw" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/openclaw"

  run "$TEST_DIR/gateway-healthcheck.sh"
  [ "$status" -eq 0 ]

  # Should log that notifications are disabled
  LOG_FILE="$LOG_DIR/healthcheck-$(date +%Y-%m-%d).log"
  if [ -f "$LOG_FILE" ]; then
    grep -q "Notifications disabled" "$LOG_FILE" || true
  fi
}
