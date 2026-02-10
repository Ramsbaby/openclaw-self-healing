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
            PKG_MANAGER="unknown"
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
    echo -e "${BLUE}[2/7] Creating directories...${NC}"

    mkdir -p "$OPENCLAW_WORKSPACE/scripts"
    mkdir -p "$OPENCLAW_WORKSPACE/memory"
    mkdir -p "$OPENCLAW_CONFIG_DIR"
    mkdir -p "$SYSTEMD_USER_DIR"

    echo -e "${GREEN}✅ Directories created${NC}"
}

# Download scripts
download_scripts() {
    echo -e "${BLUE}[3/7] Downloading scripts...${NC}"

    local scripts=(
        "gateway-healthcheck.sh"
        "emergency-recovery.sh"
        "emergency-recovery-monitor.sh"
    )

    for script in "${scripts[@]}"; do
        echo "   Downloading $script..."
        curl -sSL "$REPO_RAW/scripts/$script" -o "$OPENCLAW_WORKSPACE/scripts/$script"
        chmod 700 "$OPENCLAW_WORKSPACE/scripts/$script"
    done

    echo -e "${GREEN}✅ Scripts downloaded${NC}"
}

# Setup environment
setup_environment() {
    echo -e "${BLUE}[4/7] Setting up environment...${NC}"

    local env_file="$OPENCLAW_CONFIG_DIR/.env"

    if [[ -f "$env_file" ]]; then
        echo -e "${YELLOW}   .env already exists, preserving...${NC}"
    else
        cat > "$env_file" << 'EOF'
# OpenClaw Self-Healing System Configuration
# See: https://github.com/Ramsbaby/openclaw-self-healing

# Discord webhook for Level 4 alerts (optional)
# DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."

# Gateway settings
OPENCLAW_GATEWAY_URL="http://localhost:18789/"

# Health Check settings
HEALTH_CHECK_MAX_RETRIES=3
HEALTH_CHECK_RETRY_DELAY=30
HEALTH_CHECK_ESCALATION_WAIT=300

# Emergency Recovery settings
EMERGENCY_RECOVERY_TIMEOUT=1800
CLAUDE_WORKSPACE_TRUST_TIMEOUT=10

# Alert settings
EMERGENCY_ALERT_WINDOW=30
EOF
        chmod 600 "$env_file"
    fi

    echo -e "${GREEN}✅ Environment configured${NC}"
}

# Install systemd units
install_systemd_units() {
    echo -e "${BLUE}[5/7] Installing systemd user units...${NC}"

    local units=(
        "openclaw-gateway.service"
        "openclaw-healthcheck.service"
        "openclaw-healthcheck.timer"
        "openclaw-emergency-recovery.service"
    )

    for unit in "${units[@]}"; do
        echo "   Installing $unit..."
        curl -sSL "$REPO_RAW/systemd/$unit" -o "$SYSTEMD_USER_DIR/$unit"
    done

    # Reload systemd user daemon
    systemctl --user daemon-reload

    echo -e "${GREEN}✅ systemd units installed${NC}"
}

# Enable and start services
enable_services() {
    echo -e "${BLUE}[6/7] Enabling and starting services...${NC}"

    # Enable gateway service
    systemctl --user enable openclaw-gateway.service
    echo "   ✅ openclaw-gateway.service enabled"

    # Enable and start healthcheck timer
    systemctl --user enable openclaw-healthcheck.timer
    systemctl --user start openclaw-healthcheck.timer
    echo "   ✅ openclaw-healthcheck.timer enabled and started"

    # Emergency recovery is on-demand only (no enable)
    echo "   ℹ️  openclaw-emergency-recovery.service (on-demand, not auto-started)"

    echo -e "${GREEN}✅ Services enabled${NC}"
}

# Print summary
print_summary() {
    echo -e "${BLUE}[7/7] Installation complete!${NC}"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     🎉 Self-Healing System Installed Successfully!        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}What's installed:${NC}"
    echo "  ✅ Level 0: Gateway KeepAlive (systemd Restart=always)"
    echo "  ✅ Level 2: Health Check (systemd timer, every 5 min)"
    echo "  ✅ Level 3: Claude Emergency Recovery (on-demand)"
    echo "  ✅ Level 4: Discord Alert (requires webhook setup)"
    echo ""
    echo -e "${BLUE}Scripts location:${NC}"
    echo "  $OPENCLAW_WORKSPACE/scripts/"
    echo ""
    echo -e "${BLUE}systemd units:${NC}"
    echo "  $SYSTEMD_USER_DIR/"
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  $OPENCLAW_CONFIG_DIR/.env"
    echo ""
    echo -e "${YELLOW}⚠️  Optional: Set up Level 4 Discord alerts${NC}"
    echo "  1. Create a Discord webhook"
    echo "  2. Edit $OPENCLAW_CONFIG_DIR/.env"
    echo "  3. Add: DISCORD_WEBHOOK_URL=\"your-webhook-url\""
    echo ""
    echo -e "${BLUE}Verify installation:${NC}"
    echo "  systemctl --user status openclaw-healthcheck.timer"
    echo "  systemctl --user list-timers"
    echo "  journalctl --user -u openclaw-healthcheck -f"
    echo ""
    echo -e "${BLUE}Manual commands:${NC}"
    echo "  systemctl --user start openclaw-gateway           # Start gateway"
    echo "  systemctl --user start openclaw-emergency-recovery # Trigger Level 3"
    echo "  systemctl --user status openclaw-gateway           # Check status"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  $REPO_URL"
    echo ""
    echo -e "${GREEN}The system is now watching your watcher. Sleep well. 🦞${NC}"
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
    print_summary
}

main "$@"
