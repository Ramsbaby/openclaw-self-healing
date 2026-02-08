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

# Check OS
check_os() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${YELLOW}⚠️  This installer is optimized for macOS.${NC}"
        echo -e "${YELLOW}   For Linux, see: ${REPO_URL}/blob/main/docs/LINUX_SETUP.md${NC}"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
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
    echo -e "${BLUE}[2/6] Creating directories...${NC}"
    
    mkdir -p "$OPENCLAW_WORKSPACE/scripts"
    mkdir -p "$OPENCLAW_WORKSPACE/memory"
    mkdir -p "$OPENCLAW_CONFIG_DIR"
    mkdir -p "$HOME/Library/LaunchAgents"
    
    echo -e "${GREEN}✅ Directories created${NC}"
}

# Download scripts
download_scripts() {
    echo -e "${BLUE}[3/6] Downloading scripts...${NC}"
    
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
    echo -e "${BLUE}[4/6] Setting up environment...${NC}"
    
    local env_file="$OPENCLAW_CONFIG_DIR/.env"
    
    if [[ -f "$env_file" ]]; then
        echo -e "${YELLOW}   .env already exists, preserving...${NC}"
    else
        cat > "$env_file" << 'EOF'
# OpenClaw Self-Healing System Configuration
# See: https://github.com/Ramsbaby/openclaw-self-healing

# Discord webhook for Level 4 alerts (optional)
# Get yours at: https://support.discord.com/hc/en-us/articles/228383668
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

# Install LaunchAgent
install_launchagent() {
    echo -e "${BLUE}[5/6] Installing LaunchAgent (Level 2 Health Check)...${NC}"
    
    local plist="$HOME/Library/LaunchAgents/com.openclaw.healthcheck.plist"
    
    # Unload if exists
    if launchctl list | grep -q "com.openclaw.healthcheck"; then
        launchctl unload "$plist" 2>/dev/null || true
    fi
    
    cat > "$plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.healthcheck</string>
    <key>ProgramArguments</key>
    <array>
        <string>$OPENCLAW_WORKSPACE/scripts/gateway-healthcheck.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$OPENCLAW_WORKSPACE/memory/healthcheck-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$OPENCLAW_WORKSPACE/memory/healthcheck-stderr.log</string>
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
    
    launchctl load "$plist"
    
    echo -e "${GREEN}✅ LaunchAgent installed and loaded${NC}"
}

# Print summary
print_summary() {
    echo -e "${BLUE}[6/6] Installation complete!${NC}"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     🎉 Self-Healing System Installed Successfully!        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}What's installed:${NC}"
    echo "  ✅ Level 1: Watchdog (use existing OpenClaw watchdog)"
    echo "  ✅ Level 2: Health Check (LaunchAgent, every 5 min)"
    echo "  ✅ Level 3: Claude Emergency Recovery (on-demand)"
    echo "  ✅ Level 4: Discord Alert (requires webhook setup)"
    echo ""
    echo -e "${BLUE}Scripts location:${NC}"
    echo "  $OPENCLAW_WORKSPACE/scripts/"
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
    echo "  launchctl list | grep openclaw.healthcheck"
    echo "  tail -f $OPENCLAW_WORKSPACE/memory/healthcheck-\$(date +%Y-%m-%d).log"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  $REPO_URL"
    echo ""
    echo -e "${GREEN}The system is now watching your watcher. Sleep well. 🦞${NC}"
}

# Main
main() {
    check_os
    check_prerequisites
    create_directories
    download_scripts
    setup_environment
    install_launchagent
    print_summary
}

main "$@"
