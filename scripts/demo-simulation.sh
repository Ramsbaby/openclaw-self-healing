#!/bin/bash

# OpenClaw Self-Healing v2.0 Demo Simulation
# This script simulates the 4-level recovery process

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Typing effect function
type_text() {
    local text="$1"
    local delay="${2:-0.03}"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

# Header
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     OpenClaw Self-Healing System v2.0 - Live Demo          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
sleep 1

# Normal operation
echo -e "${GREEN}✓ Gateway running normally...${NC}"
echo -e "${GREEN}✓ All systems operational${NC}"
echo ""
sleep 2

# Simulated crash
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
type_text "🚨 Gateway crashed!" 0.05
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}Error: Segmentation fault (core dumped)${NC}"
echo -e "${RED}Process terminated unexpectedly at $(date '+%H:%M:%S')${NC}"
echo ""
sleep 2

# Level 1: Watchdog
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Level 1: Watchdog Detection                               │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
sleep 1
type_text "🔍 Level 1: Watchdog detected process termination..." 0.04
echo "   → Checking process status..."
sleep 1
echo "   → Gateway process not found (PID: none)"
sleep 1
echo -e "${YELLOW}   → Attempting automatic restart...${NC}"
sleep 1
echo -e "${GREEN}   ✓ Gateway restarted (PID: 12345)${NC}"
echo ""
sleep 2

# Level 2: Health Check
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Level 2: Health Check Validation                          │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
sleep 1
type_text "🏥 Level 2: Health check failed..." 0.04
echo "   → POST /health/liveness returned 503"
sleep 1
echo "   → Response: Connection refused"
sleep 1
echo -e "${YELLOW}   → Triggering force restart...${NC}"
sleep 1
echo "   → Killing process 12345..."
sleep 1
echo "   → Starting fresh instance..."
sleep 1
echo -e "${GREEN}   ✓ New instance started (PID: 12346)${NC}"
echo ""
sleep 2

# Level 3: Claude Doctor
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Level 3: AI-Powered Diagnostics                           │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
sleep 1
type_text "🧠 Level 3: Claude Doctor diagnosing..." 0.04
echo "   → Analyzing system logs..."
sleep 1
echo "   → Found: OOM killer activated (memory spike: 95%)"
sleep 1
echo "   → Root cause: Memory leak in session handler"
sleep 1
echo -e "${YELLOW}   → Applying mitigation...${NC}"
sleep 1
echo "   → Setting NODE_OPTIONS=--max-old-space-size=4096"
sleep 1
echo "   → Enabling aggressive garbage collection"
sleep 1
echo "   → Restarting with optimized configuration..."
sleep 1
echo -e "${GREEN}   ✓ Gateway stable with optimized settings${NC}"
echo ""
sleep 2

# Level 4: Human Escalation
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Level 4: Human Notification                               │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
sleep 1
echo "📱 Sending Discord alert to #jarvis-system..."
sleep 1
echo "   → Message: \"Gateway recovered after Level 3 intervention\""
sleep 1
echo "   → Incident ID: INC-2026-02-09-001"
sleep 1
echo -e "${GREEN}   ✓ Human notified${NC}"
echo ""
sleep 2

# Recovery successful
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
type_text "✅ Recovery successful!" 0.05
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Total recovery time: 47 seconds${NC}"
echo -e "${GREEN}All systems operational${NC}"
echo ""
sleep 2

# Metrics
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  📊 Metrics Updated                                        │${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
echo ""
echo "Recovery Statistics:"
echo "  • Total incidents today:        1"
echo "  • Level 1 success rate:         0% (failed)"
echo "  • Level 2 success rate:         0% (failed)"
echo "  • Level 3 success rate:         100% (success)"
echo "  • Level 4 escalations:          0"
echo "  • Average recovery time:        47s"
echo "  • System uptime:                99.87%"
echo ""
sleep 2

echo -e "${GREEN}Demo completed successfully!${NC}"
echo ""
