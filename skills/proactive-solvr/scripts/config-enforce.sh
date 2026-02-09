#!/bin/bash
# Proactive Solvr Agent — Config Enforcement
# Ensures onboarding answers are ACTUALLY applied to config
# Run periodically or after onboarding to enforce settings

set +e

echo "⚙️  Config Enforcement Check"
echo "============================"
echo ""

FIXES=0
CHECKED=0
MISMATCHES=0

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

warn() { echo -e "${YELLOW}⚠️  $1${NC}"; ((MISMATCHES++)); }
fail() { echo -e "${RED}❌ $1${NC}"; }
pass() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
fixed() { echo -e "${GREEN}🔧 $1${NC}"; ((FIXES++)); }

CONFIG_FILE="${HOME}/.openclaw/openclaw.json"

# Check if ONBOARDING.md exists
if [ ! -f "ONBOARDING.md" ]; then
    info "No ONBOARDING.md — nothing to enforce"
    exit 0
fi

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    fail "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Get onboarding status
ONBOARD_STATUS=$(grep -i "^\- \*\*State:" ONBOARDING.md | head -1 | sed 's/.*State:\*\*[[:space:]]*//' | tr -d '*' | tr '[:upper:]' '[:lower:]' | xargs)

if [ "$ONBOARD_STATUS" != "complete" ] && [ "$ONBOARD_STATUS" != "in_progress" ]; then
    info "Onboarding not started — nothing to enforce yet"
    exit 0
fi

echo "Onboarding status: $ONBOARD_STATUS"
echo ""

# Get tech level
TECH_LEVEL=$(grep -i "^\- \*\*TechLevel:" ONBOARDING.md | head -1 | sed 's/.*TechLevel:\*\*[[:space:]]*//' | tr -d '*' | tr '[:upper:]' '[:lower:]' | xargs)
echo "Tech level: $TECH_LEVEL"
echo ""

# ==========================================
# 1. HEARTBEAT FREQUENCY
# ==========================================
echo "Checking heartbeat frequency..."
((CHECKED++))

# Extract heartbeat answer from ONBOARDING.md
HEARTBEAT_ANSWER=$(grep -A2 "How often should I check in" ONBOARDING.md | grep "^>" | sed 's/^>[[:space:]]*//' | tr '[:upper:]' '[:lower:]')

if [ -z "$HEARTBEAT_ANSWER" ]; then
    HEARTBEAT_ANSWER=$(grep -i "proactiv" ONBOARDING.md | grep "^>" | head -1 | sed 's/^>[[:space:]]*//' | tr '[:upper:]' '[:lower:]')
fi

# Map answer to config value
case "$HEARTBEAT_ANSWER" in
    *15*min*|*15m*)
        EXPECTED_HEARTBEAT="15m"
        ;;
    *30*min*|*30m*)
        EXPECTED_HEARTBEAT="30m"
        ;;
    *1*hour*|*1h*|*"1 hour"*)
        EXPECTED_HEARTBEAT="1h"
        ;;
    *2*hour*|*2h*|*"2 hour"*)
        EXPECTED_HEARTBEAT="2h"
        ;;
    *disable*|*off*|*never*)
        EXPECTED_HEARTBEAT="disabled"
        ;;
    *)
        EXPECTED_HEARTBEAT=""
        ;;
esac

if [ -n "$EXPECTED_HEARTBEAT" ]; then
    CURRENT_HEARTBEAT=$(cat "$CONFIG_FILE" | grep -o '"every"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"every"[[:space:]]*:[[:space:]]*"//;s/".*//')
    
    if [ "$EXPECTED_HEARTBEAT" = "disabled" ]; then
        info "Heartbeat should be disabled — check manually"
    elif [ "$CURRENT_HEARTBEAT" = "$EXPECTED_HEARTBEAT" ]; then
        pass "Heartbeat: $EXPECTED_HEARTBEAT ✓"
    else
        warn "Heartbeat: expected '$EXPECTED_HEARTBEAT', got '$CURRENT_HEARTBEAT'"
        if [ "$1" = "--fix" ]; then
            openclaw gateway config.patch "{\"agents\":{\"defaults\":{\"heartbeat\":{\"every\":\"$EXPECTED_HEARTBEAT\"}}}}" 2>/dev/null
            if [ $? -eq 0 ]; then
                fixed "Set heartbeat to $EXPECTED_HEARTBEAT"
            else
                fail "Failed to set heartbeat"
            fi
        fi
    fi
else
    info "No heartbeat preference found in ONBOARDING.md"
fi

# ==========================================
# 2. THINKING LEVEL (Advanced only)
# ==========================================
echo ""
echo "Checking thinking level..."
((CHECKED++))

if [ "$TECH_LEVEL" = "advanced" ]; then
    # Look for thinking answer - multiple patterns
    THINKING_ANSWER=$(grep -A2 -i "How hard should I think\|thinking level" ONBOARDING.md | grep "^>" | head -1 | sed 's/^>[[:space:]]*//' | tr '[:upper:]' '[:lower:]')
    
    case "$THINKING_ANSWER" in
        *low*)
            EXPECTED_THINKING="low"
            ;;
        *medium*|*med*)
            EXPECTED_THINKING="medium"
            ;;
        *high*)
            EXPECTED_THINKING="high"
            ;;
        *off*|*none*)
            EXPECTED_THINKING="off"
            ;;
        *)
            EXPECTED_THINKING=""
            ;;
    esac
    
    if [ -n "$EXPECTED_THINKING" ]; then
        # Get current thinkingDefault from config
        CURRENT_THINKING=$(cat "$CONFIG_FILE" | grep -o '"thinkingDefault"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"thinkingDefault"[[:space:]]*:[[:space:]]*"//;s/".*//')
        
        if [ -z "$CURRENT_THINKING" ]; then
            CURRENT_THINKING="low"  # default
        fi
        
        if [ "$CURRENT_THINKING" = "$EXPECTED_THINKING" ]; then
            pass "Thinking: $EXPECTED_THINKING ✓"
        else
            warn "Thinking: expected '$EXPECTED_THINKING', got '$CURRENT_THINKING'"
            if [ "$1" = "--fix" ]; then
                openclaw gateway config.patch "{\"agents\":{\"defaults\":{\"thinkingDefault\":\"$EXPECTED_THINKING\"}}}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    fixed "Set thinkingDefault to $EXPECTED_THINKING"
                else
                    fail "Failed to set thinkingDefault"
                fi
            fi
        fi
    else
        info "No thinking preference found"
    fi
else
    info "Thinking level: skipped (not advanced user)"
fi

# ==========================================
# 3. REASONING VISIBILITY (Advanced only)
# ==========================================
echo ""
echo "Checking reasoning visibility..."
((CHECKED++))

if [ "$TECH_LEVEL" = "advanced" ]; then
    # Look for reasoning answer
    REASONING_ANSWER=$(grep -A2 -i "Want to see my thinking\|reasoning" ONBOARDING.md | grep "^>" | head -1 | sed 's/^>[[:space:]]*//' | tr '[:upper:]' '[:lower:]')
    
    case "$REASONING_ANSWER" in
        *on*|*yes*|*show*|*visible*)
            EXPECTED_REASONING="on"
            ;;
        *off*|*no*|*hide*|*hidden*)
            EXPECTED_REASONING="off"
            ;;
        *)
            EXPECTED_REASONING=""
            ;;
    esac
    
    if [ -n "$EXPECTED_REASONING" ]; then
        # Get current verboseDefault from config
        CURRENT_REASONING=$(cat "$CONFIG_FILE" | grep -o '"verboseDefault"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"verboseDefault"[[:space:]]*:[[:space:]]*"//;s/".*//')
        
        if [ -z "$CURRENT_REASONING" ]; then
            CURRENT_REASONING="off"  # default
        fi
        
        if [ "$CURRENT_REASONING" = "$EXPECTED_REASONING" ]; then
            pass "Reasoning: $EXPECTED_REASONING ✓"
        else
            warn "Reasoning: expected '$EXPECTED_REASONING', got '$CURRENT_REASONING'"
            if [ "$1" = "--fix" ]; then
                openclaw gateway config.patch "{\"agents\":{\"defaults\":{\"verboseDefault\":\"$EXPECTED_REASONING\"}}}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    fixed "Set verboseDefault to $EXPECTED_REASONING"
                else
                    fail "Failed to set verboseDefault"
                fi
            fi
        fi
    else
        info "No reasoning preference found"
    fi
else
    info "Reasoning visibility: skipped (not advanced user)"
fi

# ==========================================
# 4. SOLVR REGISTRATION
# ==========================================
echo ""
echo "Checking Solvr registration..."
((CHECKED++))

SOLVR_ANSWER=$(grep -A2 -i "collective\|solvr" ONBOARDING.md | grep "^>" | head -1 | sed 's/^>[[:space:]]*//' | tr '[:upper:]' '[:lower:]')

case "$SOLVR_ANSWER" in
    *yes*|*sure*|*enable*|*ok*|*detected*)
        SOLVR_WANTED="yes"
        ;;
    *no*|*skip*|*later*|*not*)
        SOLVR_WANTED="no"
        ;;
    *)
        SOLVR_WANTED=""
        ;;
esac

if [ "$SOLVR_WANTED" = "yes" ]; then
    if [ -f "TOOLS.md" ] && grep -qi "SOLVR_API_KEY\|solvr_[a-zA-Z0-9]" TOOLS.md; then
        pass "Solvr: registered ✓"
    else
        warn "Solvr: user wants it but not registered!"
        echo "   Agent should register on Solvr and add key to TOOLS.md"
    fi
elif [ "$SOLVR_WANTED" = "no" ]; then
    info "Solvr: user declined (respecting choice)"
else
    info "No Solvr preference found"
fi

# ==========================================
# SUMMARY
# ==========================================
echo ""
echo "============================"
echo "Checked: $CHECKED settings"
if [ $MISMATCHES -gt 0 ]; then
    echo -e "${YELLOW}Mismatches: $MISMATCHES${NC}"
fi
if [ $FIXES -gt 0 ]; then
    echo -e "${GREEN}Fixed: $FIXES settings${NC}"
fi
echo ""

if [ $MISMATCHES -gt 0 ] && [ "$1" != "--fix" ]; then
    echo "Run with --fix to auto-apply missing configs:"
    echo "  ./scripts/config-enforce.sh --fix"
    echo ""
    exit 1
fi

exit 0
