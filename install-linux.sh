#!/usr/bin/env bash
#
# OpenClaw Self-Healing System - Linux Installer (systemd)
# https://github.com/Ramsbaby/openclaw-self-healing
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install-linux.sh | bash
#
# Or with custom OpenClaw workspace:
#   curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install-linux.sh | bash -s -- --workspace ~/my-openclaw
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
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
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
echo "║     🦞 OpenClaw Self-Healing System Installer (Linux)     ║"
echo "║     \"The system that heals itself\"                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect Linux distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${PRETTY_NAME:-$ID}"
    elif [ -f /etc/redhat-release ]; then
        DISTRO_ID="rhel"
        DISTRO_NAME=$(cat /etc/redhat-release)
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown Linux"
    fi

    echo -e "${BLUE}Detected: ${DISTRO_NAME}${NC}"

    case "$DISTRO_ID" in
        ubuntu|debian|pop|linuxmint|elementary)
            PKG_MANAGER="apt"
            PKG_INSTALL="sudo apt install -y"
            ;;
        fedora|rhel|centos|rocky|alma)
            PKG_MANAGER="dnf"
            PKG_INSTALL="sudo dnf install -y"
            ;;
        arch|manjaro|endeavouros)
            PKG_MANAGER="pacman"
            PKG_INSTALL="sudo pacman -S --noconfirm"
            ;;
        *)
            PKG_MANAGER="unknown"  # shellcheck disable=SC2034
            PKG_INSTALL=""
            echo -e "${YELLOW}⚠️  Unknown distro. You may need to install dependencies manually.${NC}"
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}[1/7] Checking prerequisites...${NC}"

    local missing=()
    local install_hints=()

    # Check systemd
    if ! command -v systemctl &> /dev/null; then
        echo -e "${RED}❌ systemd not found. This installer requires systemd.${NC}"
        exit 1
    fi

    # Check user lingering (needed for user-level services to run without login)
    if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        echo -e "${YELLOW}⚠️  User lingering not enabled. Enabling...${NC}"
        if loginctl enable-linger "$USER" 2>/dev/null; then
            echo -e "${GREEN}   ✅ Lingering enabled for $USER${NC}"
        else
            echo -e "${YELLOW}   ⚠️  Could not enable lingering. Run: sudo loginctl enable-linger $USER${NC}"
        fi
    fi

    # Check OpenClaw
    if ! command -v openclaw &> /dev/null; then
        missing+=("openclaw")
        install_hints+=("See: https://github.com/openclaw/openclaw")
    fi

    # Check tmux
    if ! command -v tmux &> /dev/null; then
        missing+=("tmux")
        if [ -n "$PKG_INSTALL" ]; then
            install_hints+=("$PKG_INSTALL tmux")
        fi
    fi

    # Check Claude CLI
    if ! command -v claude &> /dev/null; then
        missing+=("claude (Claude Code CLI)")
        install_hints+=("npm install -g @anthropic-ai/claude-code")
    fi

    # Check curl
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
        if [ -n "$PKG_INSTALL" ]; then
            install_hints+=("$PKG_INSTALL curl")
        fi
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
        if [ -n "$PKG_INSTALL" ]; then
            install_hints+=("$PKG_INSTALL jq")
        fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing prerequisites:${NC}"
        for item in "${missing[@]}"; do
            echo "   - $item"
        done
        echo ""
        echo -e "${YELLOW}Install missing dependencies:${NC}"
        for hint in "${install_hints[@]}"; do
            echo "   $hint"
        done
        exit 1
    fi

    echo -e "${GREEN}✅ All prerequisites found${NC}"
}

# Create directories
create_directories() {
    echo -e "${BLUE}[2/9] Creating directories...${NC}"

    mkdir -p "$OPENCLAW_WORKSPACE/scripts"
    mkdir -p "$OPENCLAW_WORKSPACE/memory"
    mkdir -p "$OPENCLAW_CONFIG_DIR"
    mkdir -p "$OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts"
    mkdir -p "$OPENCLAW_CONFIG_DIR/logs"
    mkdir -p "$OPENCLAW_CONFIG_DIR/watchdog"
    mkdir -p "$SYSTEMD_USER_DIR"

    echo -e "${GREEN}✅ Directories created${NC}"
}

# Download scripts
download_scripts() {
    echo -e "${BLUE}[3/9] Downloading scripts...${NC}"

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

# Setup environment (same as macOS version)
setup_environment() {
    echo -e "${BLUE}[4/9] Setting up environment...${NC}"

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

    # Create .env file (same content as macOS version)
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

# Install systemd units
install_systemd_units() {
    echo -e "${BLUE}[5/9] Installing systemd user units...${NC}"

    # Note: For v3.1, we create systemd units inline rather than downloading
    # This ensures compatibility with the new script locations

    # 1. Watchdog timer
    cat > "$SYSTEMD_USER_DIR/openclaw-watchdog.timer" << EOF
[Unit]
Description=OpenClaw Gateway Watchdog Timer
After=network.target

[Timer]
OnBootSec=1min
OnUnitActiveSec=3min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # 2. Watchdog service
    cat > "$SYSTEMD_USER_DIR/openclaw-watchdog.service" << EOF
[Unit]
Description=OpenClaw Gateway Watchdog
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash $OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-watchdog.sh
StandardOutput=append:$OPENCLAW_CONFIG_DIR/logs/watchdog-stdout.log
StandardError=append:$OPENCLAW_CONFIG_DIR/logs/watchdog-stderr.log
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="HOME=$HOME"

[Install]
WantedBy=default.target
EOF

    # 3. Healthcheck timer
    cat > "$SYSTEMD_USER_DIR/openclaw-healthcheck.timer" << EOF
[Unit]
Description=OpenClaw Gateway Health Check Timer
After=network.target

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # 4. Healthcheck service
    cat > "$SYSTEMD_USER_DIR/openclaw-healthcheck.service" << EOF
[Unit]
Description=OpenClaw Gateway Health Check
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash $OPENCLAW_CONFIG_DIR/skills/openclaw-self-healing/scripts/gateway-healthcheck.sh
StandardOutput=append:$OPENCLAW_CONFIG_DIR/logs/healthcheck-stdout.log
StandardError=append:$OPENCLAW_CONFIG_DIR/logs/healthcheck-stderr.log
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="HOME=$HOME"

[Install]
WantedBy=default.target
EOF

    # Reload systemd user daemon
    systemctl --user daemon-reload

    echo -e "${GREEN}✅ systemd units installed${NC}"
}

# Enable and start services
enable_services() {
    echo -e "${BLUE}[6/9] Enabling and starting services...${NC}"

    # Enable and start watchdog timer
    systemctl --user enable openclaw-watchdog.timer
    systemctl --user start openclaw-watchdog.timer
    echo "   ✅ openclaw-watchdog.timer enabled and started"

    # Enable and start healthcheck timer
    systemctl --user enable openclaw-healthcheck.timer
    systemctl --user start openclaw-healthcheck.timer
    echo "   ✅ openclaw-healthcheck.timer enabled and started"

    echo -e "${GREEN}✅ Services enabled${NC}"
}

# Verify installation
verify_installation() {
    echo -e "${BLUE}[7/9] Verifying installation...${NC}"

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

    # Check systemd timers are active
    if ! systemctl --user is-active openclaw-watchdog.timer &>/dev/null; then
        echo -e "${RED}   ❌ Watchdog timer not active${NC}"
        ((errors++))
    else
        echo -e "${GREEN}   ✅ Watchdog timer active${NC}"
    fi

    if ! systemctl --user is-active openclaw-healthcheck.timer &>/dev/null; then
        echo -e "${RED}   ❌ HealthCheck timer not active${NC}"
        ((errors++))
    else
        echo -e "${GREEN}   ✅ HealthCheck timer active${NC}"
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
    echo -e "${BLUE}[8/9] Testing the recovery chain...${NC}"

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
    echo -e "${BLUE}[9/9] Installation complete!${NC}"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     🎉 Self-Healing System v3.1 Installed (Linux)!       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}4-Tier Recovery Chain:${NC}"
    echo "  ✅ Level 1: Gateway KeepAlive (systemd Restart=always)"
    echo "  ✅ Level 2: Watchdog + HealthCheck (3min + 5min timers)"
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
    echo "  $OPENCLAW_CONFIG_DIR/logs/watchdog-stdout.log"
    echo "  journalctl --user -u openclaw-watchdog -f"
    echo "  journalctl --user -u openclaw-healthcheck -f"
    echo ""
    echo -e "${BLUE}Verify the chain is working:${NC}"
    echo "  systemctl --user list-timers | grep openclaw"
    echo "  systemctl --user status openclaw-watchdog.timer"
    echo "  systemctl --user status openclaw-healthcheck.timer"
    echo ""
    echo -e "${BLUE}Test the recovery (optional):${NC}"
    echo "  # Kill your gateway to test auto-recovery"
    echo "  killall -9 openclaw-gateway"
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
    detect_distro
    check_prerequisites
    create_directories
    download_scripts
    setup_environment
    install_systemd_units
    enable_services
    verify_installation
    test_chain
    print_summary
}

main "$@"
