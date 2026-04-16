#!/usr/bin/env bash
set -euo pipefail

# validate-deployment.sh — Verify self-healing system is properly configured
# Run after installation to catch common deployment issues

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
ENV_FILE="$OPENCLAW_HOME/.env"
PASS=0
FAIL=0
WARN=0

pass()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn()  { echo "  ⚠️  $1"; WARN=$((WARN+1)); }
header() { echo ""; echo "=== $1 ==="; }

echo "🔍 OpenClaw Self-Healing Deployment Validation"
echo "================================================"

# --- Level 0: Preflight ---
header "Level 0: Preflight Validation"

if [[ -f "$OPENCLAW_HOME/scripts/gateway-preflight.sh" ]]; then
    pass "Preflight script exists"
else
    fail "Preflight script not found at $OPENCLAW_HOME/scripts/gateway-preflight.sh"
fi

if [[ -f "$ENV_FILE" ]]; then
    pass ".env file exists"
    for key in OPENCLAW_GATEWAY_TOKEN DISCORD_WEBHOOK_URL; do
        if grep -qE "^${key}=.+" "$ENV_FILE" 2>/dev/null; then
            pass ".env key present: $key"
        else
            warn ".env key missing or empty: $key"
        fi
    done
else
    fail ".env file not found at $ENV_FILE"
fi

NODE_BIN="${NODE_BIN:-$(command -v node 2>/dev/null || echo "")}"
if [[ -n "$NODE_BIN" && -x "$NODE_BIN" ]]; then
    pass "Node.js binary found: $NODE_BIN"
    if "$NODE_BIN" -e "process.exit(0)" 2>/dev/null; then
        pass "Node.js smoke test passed"
    else
        fail "Node.js binary exists but smoke test failed"
    fi
else
    fail "Node.js binary not found"
fi

# --- Level 1: KeepAlive ---
header "Level 1: KeepAlive"

if [[ "$(uname)" == "Darwin" ]]; then
    if launchctl list 2>/dev/null | grep -q "openclaw"; then
        pass "LaunchAgent loaded"
    else
        warn "No openclaw LaunchAgent loaded (check installation)"
    fi
elif command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
        pass "systemd service active"
    else
        warn "systemd service not active"
    fi
fi

# --- Level 2: Watchdog ---
header "Level 2: Watchdog"

if [[ -f "$OPENCLAW_HOME/scripts/gateway-watchdog.sh" ]]; then
    pass "Watchdog script exists"
else
    fail "Watchdog script not found"
fi

if [[ -f "$OPENCLAW_HOME/logs/watchdog.log" ]]; then
    log_age=$(( $(date +%s) - $(stat -c '%Y' "$OPENCLAW_HOME/logs/watchdog.log" 2>/dev/null || stat -f %m "$OPENCLAW_HOME/logs/watchdog.log" 2>/dev/null || echo 0) ))
    if (( log_age < 600 )); then
        pass "Watchdog log recent (${log_age}s ago)"
    else
        warn "Watchdog log stale (${log_age}s ago)"
    fi
else
    warn "No watchdog log found"
fi

# --- Level 3: AI Emergency Recovery ---
header "Level 3: AI Emergency Recovery"

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "/opt/homebrew/bin/claude")}"
if [[ -x "$CLAUDE_BIN" ]]; then
    pass "Claude CLI found: $CLAUDE_BIN"
else
    # POSIX-compatible extraction (grep -oP is GNU-only, fails on macOS BSD grep)
    LLM_PROVIDER=$(grep "^OPENCLAW_LLM_PROVIDER=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo "claude")
    LLM_PROVIDER="${LLM_PROVIDER:-claude}"
    if [[ "$LLM_PROVIDER" == "claude" ]]; then
        fail "Claude CLI not found at $CLAUDE_BIN (required for default LLM provider)"
    else
        pass "Non-Claude LLM provider configured: $LLM_PROVIDER"
    fi
fi

if command -v tmux >/dev/null 2>&1; then
    pass "tmux available"
else
    fail "tmux not installed (required for Level 3 PTY sessions)"
fi

# --- Level 4: Human Alert ---
header "Level 4: Human Alert"

if [[ -f "$OPENCLAW_HOME/.env" ]]; then
    if grep -qE "^DISCORD_WEBHOOK_URL=.+" "$ENV_FILE" 2>/dev/null; then
        pass "Discord webhook configured"
    else
        warn "Discord webhook not configured"
    fi
    if grep -qE "^SLACK_WEBHOOK_URL=.+" "$ENV_FILE" 2>/dev/null; then
        pass "Slack webhook configured"
    else
        warn "Slack webhook not configured (optional)"
    fi
    if grep -qE "^TELEGRAM_BOT_TOKEN=.+" "$ENV_FILE" 2>/dev/null; then
        pass "Telegram configured"
    else
        warn "Telegram not configured (optional)"
    fi
fi

# --- Summary ---
echo ""
echo "================================================"
echo "Results: ✅ $PASS passed, ❌ $FAIL failed, ⚠️  $WARN warnings"
if (( FAIL > 0 )); then
    echo "🚨 Fix the failures above before relying on self-healing."
    exit 1
elif (( WARN > 2 )); then
    echo "⚠️  Review warnings — some recovery levels may not work."
    exit 0
else
    echo "✅ Self-healing system looks healthy!"
    exit 0
fi
