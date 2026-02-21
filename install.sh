#!/usr/bin/env bash
#
# OpenClaw Self-Healing System - One-Click Installer
# https://github.com/Ramsbaby/openclaw-self-healing
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash
#
# Or with custom OpenClaw workspace:
#   curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash -s -- --workspace ~/my-openclaw
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Defaults
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/openclaw}"
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
REPO_URL="https://github.com/Ramsbaby/openclaw-self-healing"
REPO_RAW="https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace)
            OPENCLAW_WORKSPACE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--workspace PATH]"
            echo ""
            echo "Options:"
            echo "  --workspace PATH    OpenClaw workspace directory (default: ~/openclaw)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     🦞 OpenClaw Self-Healing System Installer             ║"
echo "║     \"The system that heals itself\"                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check OS — route Linux to dedicated installer
check_os() {
    case "$(uname -s)" in
        Darwin)
            echo -e "${GREEN}Detected: macOS${NC}"
            ;;
        Linux)
            echo -e "${BLUE}Detected: Linux — launching Linux installer...${NC}"
            echo ""
            local script_dir
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [[ -f "$script_dir/install-linux.sh" ]]; then
                exec bash "$script_dir/install-linux.sh" "$@"
            fi
            # Fallback: download and run
            exec bash <(curl -sSL "$REPO_RAW/install-linux.sh") "$@"
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS: $(uname -s)${NC}"
            echo -e "${YELLOW}   Supported: macOS, Linux${NC}"
            exit 1
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}[1/6] Checking prerequisites...${NC}"
    
    local missing=()
    
    # Check OpenClaw
    if ! command -v openclaw &> /dev/null; then
        missing+=("openclaw")
    fi
    
    # Check tmux
    if ! command -v tmux &> /dev/null; then
        missing+=("tmux")
    fi
    
    # Check Claude CLI
    if ! command -v claude &> /dev/null; then
        missing+=("claude (Claude Code CLI)")
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing prerequisites:${NC}"
        for item in "${missing[@]}"; do
            echo "   - $item"
        done
        echo ""
        echo -e "${YELLOW}Install missing dependencies:${NC}"
        echo "  brew install tmux"
        echo "  npm install -g @anthropic-ai/claude-code"
        echo "  # OpenClaw: https://github.com/openclaw/openclaw"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites found${NC}"
}

# Create directories
create_directories() {
    echo -e "${BLUE}[2/8] Creating directories...${NC}"

    mkdir -p "$OPENCLAW_WORKSPACE/scripts"
    mkdir -p "$OPENCLAW_WORKSPACE/memory"
    mkdir -p "$OPENCLAW_CONFIG_DIR"
    mkdir -p "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts"
    mkdir -p "$OPENCLAW_CONFIG_DIR/logs"
    mkdir -p "$OPENCLAW_CONFIG_DIR/watchdog"
    mkdir -p "$HOME/Library/LaunchAgents"

    echo -e "${GREEN}✅ Directories created${NC}"
}

# Download scripts
download_scripts() {
    echo -e "${BLUE}[3/8] Downloading scripts...${NC}"

    local scripts=(
        "gateway-watchdog.sh"
        "gateway-healthcheck.sh"
        "emergency-recovery-v2.sh"
        "emergency-recovery-monitor.sh"
    )

    # Download from skills directory structure
    local base_url="$REPO_RAW/skills/openclaw-self-healing/scripts"

    for script in "${scripts[@]}"; do
        echo "   Downloading $script..."
        curl -sSL "$base_url/$script" -o "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/$script"
        chmod 700 "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/$script"
    done

    echo -e "${GREEN}✅ Scripts downloaded${NC}"
}

# Setup environment
setup_environment() {
    echo -e "${BLUE}[4/8] Setting up environment...${NC}"

    local env_file="$OPENCLAW_CONFIG_DIR/.env"

    if [[ -f "$env_file" ]]; then
        echo -e "${YELLOW}   .env already exists, preserving...${NC}"
        return
    fi

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Optional: Discord Webhook for Level 4 Alerts${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "When all automated recovery fails, the system can notify you via Discord."
    echo "This is optional - the system works without it (just no human alerts)."
    echo ""
    echo "To get a Discord webhook:"
    echo "  1. Go to your Discord server → Server Settings → Integrations"
    echo "  2. Click 'Create Webhook' or 'View Webhooks'"
    echo "  3. Copy the webhook URL"
    echo ""
    echo -ne "${BLUE}Enter Discord webhook URL (or press Enter to skip): ${NC}"
    read -r discord_webhook
    echo ""

    # Gateway port
    echo -ne "${BLUE}OpenClaw Gateway port [18789]: ${NC}"
    read -r gateway_port
    gateway_port="${gateway_port:-18789}"

    # Create .env file
    cat > "$env_file" << EOF
# OpenClaw Self-Healing System Configuration (v3.1)
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# ============================================
# Notifications (Level 4 Alerts)
# ============================================

# Discord webhook for critical failure alerts
$(if [ -n "$discord_webhook" ]; then echo "DISCORD_WEBHOOK_URL=\"$discord_webhook\""; else echo "# DISCORD_WEBHOOK_URL=\"https://discord.com/api/webhooks/...\""; fi)

# Telegram (optional)
# TELEGRAM_BOT_TOKEN="your_bot_token"
# TELEGRAM_CHAT_ID="your_chat_id"

# ============================================
# Gateway Configuration
# ============================================

OPENCLAW_GATEWAY_URL="http://localhost:${gateway_port}/"
OPENCLAW_GATEWAY_PORT="${gateway_port}"

# Memory directory for logs and reports
OPENCLAW_MEMORY_DIR="\$HOME/openclaw/memory"

# ============================================
# Watchdog Configuration (Level 2)
# ============================================

# HTTP request timeout (seconds)
OPENCLAW_WATCHDOG_HEALTH_TIMEOUT=5

# Maximum restart retries before Level 3 escalation
OPENCLAW_WATCHDOG_MAX_RETRIES=6

# Crash counter auto-reset (hours)
OPENCLAW_WATCHDOG_CRASH_DECAY_HOURS=6

# Memory thresholds (MB)
OPENCLAW_WATCHDOG_MEMORY_WARN_MB=1536
OPENCLAW_WATCHDOG_MEMORY_CRITICAL_MB=2048

# Level 3 escalation delay (seconds)
OPENCLAW_WATCHDOG_ESCALATE_TO_L3_AFTER=1800

# ============================================
# Health Check Configuration (Level 2)
# ============================================

HEALTH_CHECK_MAX_RETRIES=3
HEALTH_CHECK_RETRY_DELAY=30
HEALTH_CHECK_ESCALATION_WAIT=300
HEALTH_CHECK_HTTP_TIMEOUT=10

# ============================================
# Emergency Recovery Configuration (Level 3)
# ============================================

EMERGENCY_RECOVERY_TIMEOUT=1800
CLAUDE_WORKSPACE_TRUST_TIMEOUT=10
CLAUDE_STARTUP_WAIT=5
WORKSPACE_TRUST_CONFIRM_WAIT=3

# ============================================
# Emergency Monitor (Level 4)
# ============================================

EMERGENCY_ALERT_WINDOW=30
EOF

    chmod 600 "$env_file"

    echo -e "${GREEN}✅ Environment configured${NC}"
    if [ -n "$discord_webhook" ]; then
        echo -e "${GREEN}   Discord alerts: ENABLED${NC}"
    else
        echo -e "${YELLOW}   Discord alerts: DISABLED (can configure later in $env_file)${NC}"
    fi
}

# Install LaunchAgents
install_launchagents() {
    echo -e "${BLUE}[5/8] Installing LaunchAgents (Level 2 Watchdog + HealthCheck)...${NC}"

    # ========================================
    # 1. Watchdog LaunchAgent (Primary Level 2)
    # ========================================
    local watchdog_plist="$HOME/Library/LaunchAgents/ai.openclaw.watchdog.plist"

    # Unload if exists
    if launchctl list 2>/dev/null | grep -q "ai.openclaw.watchdog"; then
        launchctl bootout "gui/$(id -u)/ai.openclaw.watchdog" 2>/dev/null || true
    fi

    cat > "$watchdog_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.openclaw.watchdog</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-watchdog.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>180</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$OPENCLAW_CONFIG_DIR/logs/watchdog-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$OPENCLAW_CONFIG_DIR/logs/watchdog-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
</dict>
</plist>
EOF

    launchctl bootstrap "gui/$(id -u)" "$watchdog_plist" 2>/dev/null || launchctl load "$watchdog_plist"
    echo -e "${GREEN}   ✅ Watchdog LaunchAgent installed (runs every 3 minutes)${NC}"

    # ========================================
    # 2. HealthCheck LaunchAgent (Secondary Level 2)
    # ========================================
    local healthcheck_plist="$HOME/Library/LaunchAgents/com.openclaw.healthcheck.plist"

    # Unload if exists
    if launchctl list 2>/dev/null | grep -q "com.openclaw.healthcheck"; then
        launchctl bootout "gui/$(id -u)/com.openclaw.healthcheck" 2>/dev/null || true
    fi

    cat > "$healthcheck_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.healthcheck</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-healthcheck.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$OPENCLAW_CONFIG_DIR/logs/healthcheck-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$OPENCLAW_CONFIG_DIR/logs/healthcheck-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
</dict>
</plist>
EOF

    launchctl bootstrap "gui/$(id -u)" "$healthcheck_plist" 2>/dev/null || launchctl load "$healthcheck_plist"
    echo -e "${GREEN}   ✅ HealthCheck LaunchAgent installed (runs every 5 minutes)${NC}"

    echo -e "${GREEN}✅ LaunchAgents installed and loaded${NC}"
}

# Verify installation
verify_installation() {
    echo -e "${BLUE}[6/8] Verifying installation...${NC}"

    local errors=0

    # Check scripts exist
    local scripts=(
        "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-watchdog.sh"
        "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-healthcheck.sh"
        "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/emergency-recovery-v2.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            echo -e "${RED}   ❌ Missing: $script${NC}"
            ((errors++))
        fi
    done

    # Check LaunchAgents are loaded
    if ! launchctl list 2>/dev/null | grep -q "ai.openclaw.watchdog"; then
        echo -e "${RED}   ❌ Watchdog LaunchAgent not loaded${NC}"
        ((errors++))
    else
        echo -e "${GREEN}   ✅ Watchdog LaunchAgent active${NC}"
    fi

    if ! launchctl list 2>/dev/null | grep -q "com.openclaw.healthcheck"; then
        echo -e "${RED}   ❌ HealthCheck LaunchAgent not loaded${NC}"
        ((errors++))
    else
        echo -e "${GREEN}   ✅ HealthCheck LaunchAgent active${NC}"
    fi

    # Check .env exists
    if [[ ! -f "$OPENCLAW_CONFIG_DIR/.env" ]]; then
        echo -e "${RED}   ❌ .env file not found${NC}"
        ((errors++))
    else
        echo -e "${GREEN}   ✅ Configuration file present${NC}"
    fi

    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}✅ All verification checks passed${NC}"
        return 0
    else
        echo -e "${RED}⚠️  $errors verification check(s) failed${NC}"
        return 1
    fi
}

# Test the chain
test_chain() {
    echo -e "${BLUE}[7/8] Testing the recovery chain...${NC}"

    echo "   Testing script syntax..."

    # Test each script
    if bash -n "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-watchdog.sh" 2>/dev/null; then
        echo -e "${GREEN}   ✅ gateway-watchdog.sh syntax OK${NC}"
    else
        echo -e "${RED}   ❌ gateway-watchdog.sh has syntax errors${NC}"
    fi

    if bash -n "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-healthcheck.sh" 2>/dev/null; then
        echo -e "${GREEN}   ✅ gateway-healthcheck.sh syntax OK${NC}"
    else
        echo -e "${RED}   ❌ gateway-healthcheck.sh has syntax errors${NC}"
    fi

    if bash -n "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/emergency-recovery-v2.sh" 2>/dev/null; then
        echo -e "${GREEN}   ✅ emergency-recovery-v2.sh syntax OK${NC}"
    else
        echo -e "${RED}   ❌ emergency-recovery-v2.sh has syntax errors${NC}"
    fi

    echo -e "${GREEN}✅ Chain test complete${NC}"
}

# Print summary
print_summary() {
    echo -e "${BLUE}[8/8] Installation complete!${NC}"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     🎉 Self-Healing System v3.1 Installed!               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}4-Tier Recovery Chain:${NC}"
    echo "  ✅ Level 1: Gateway KeepAlive (instant restart)"
    echo "  ✅ Level 2: Watchdog + HealthCheck (3min + 5min intervals)"
    echo "  ✅ Level 3: Claude AI Emergency Recovery (auto-trigger after 30min failure)"
    echo "  ✅ Level 4: Discord/Telegram Alerts (human escalation)"
    echo ""
    echo -e "${BLUE}Scripts location:${NC}"
    echo "  $OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/"
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  $OPENCLAW_CONFIG_DIR/.env"
    echo ""
    echo -e "${BLUE}Logs:${NC}"
    echo "  $OPENCLAW_CONFIG_DIR/logs/watchdog.log"
    echo "  $OPENCLAW_CONFIG_DIR/logs/healthcheck-*.log"
    echo ""
    echo -e "${BLUE}Verify the chain is working:${NC}"
    echo "  launchctl list | grep -E 'watchdog|healthcheck'"
    echo "  tail -f $OPENCLAW_CONFIG_DIR/logs/watchdog.log"
    echo ""
    echo -e "${BLUE}Test the recovery (optional):${NC}"
    echo "  # Kill your gateway to test auto-recovery"
    echo "  kill -9 \$(pgrep -f openclaw.*gateway)"
    echo "  # Wait 3 minutes, check logs to see recovery in action"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  $REPO_URL"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}The system is now watching your watcher. Sleep well. 🦞${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main
main() {
    check_os
    check_prerequisites
    create_directories
    download_scripts
    setup_environment
    install_launchagents
    verify_installation
    test_chain
    print_summary
}

main "$@"
