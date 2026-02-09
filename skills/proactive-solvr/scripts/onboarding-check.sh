#!/bin/bash
# Proactive Solvr Agent — Onboarding Consistency Check
# Ensures onboarding was actually used, not bypassed
# Supports conditional onboarding (simple/intermediate/advanced)

set +e

echo "📋 Onboarding Consistency Check"
echo "================================"
echo ""

ISSUES=0

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; ((ISSUES++)); }
pass() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check if ONBOARDING.md exists
if [ ! -f "ONBOARDING.md" ]; then
    warn "No ONBOARDING.md found — onboarding not set up"
    exit 0
fi

# Get onboarding status
ONBOARD_STATUS=$(grep -i "state:" ONBOARDING.md | head -1 | sed 's/.*state:[[:space:]]*//' | tr -d '*' | tr '[:upper:]' '[:lower:]')
echo "Onboarding status: $ONBOARD_STATUS"

# Get tech level (new conditional feature)
TECH_LEVEL=$(grep -i "TechLevel:" ONBOARDING.md | head -1 | sed 's/.*TechLevel:[[:space:]]*//' | tr -d '*' | tr '[:upper:]' '[:lower:]')
if [ -z "$TECH_LEVEL" ] || [ "$TECH_LEVEL" = "not_set" ]; then
    TECH_LEVEL="not_set"
    echo "Tech level: not set (first question not answered)"
else
    echo "Tech level: $TECH_LEVEL"
fi
echo ""

# Expected questions based on tech level
case "$TECH_LEVEL" in
    simple)
        EXPECTED_QUESTIONS=8
        EXPECTS_SOLVR="no"
        EXPECTS_WEBHOOKS="no"
        ;;
    intermediate)
        EXPECTED_QUESTIONS=12
        EXPECTS_SOLVR="yes"
        EXPECTS_WEBHOOKS="no"
        ;;
    advanced)
        EXPECTED_QUESTIONS=20
        EXPECTS_SOLVR="yes"
        EXPECTS_WEBHOOKS="yes"
        ;;
    *)
        EXPECTED_QUESTIONS=0
        EXPECTS_SOLVR="unknown"
        EXPECTS_WEBHOOKS="unknown"
        ;;
esac

if [ "$TECH_LEVEL" != "not_set" ]; then
    info "Expected questions for $TECH_LEVEL level: $EXPECTED_QUESTIONS"
    echo ""
fi

# Check SOUL.md
echo "Checking SOUL.md..."
if [ -f "SOUL.md" ]; then
    SOUL_LINES=$(grep -v "^#\|^$\|^\[.*\]\|^-\s*$" SOUL.md | wc -l)
    
    if [ "$SOUL_LINES" -gt 5 ]; then
        SOUL_FILLED="yes"
        pass "SOUL.md has content ($SOUL_LINES lines)"
    else
        SOUL_FILLED="no"
        echo "   SOUL.md appears to be template only"
    fi
else
    SOUL_FILLED="no"
    echo "   SOUL.md not found"
fi

# Check USER.md
echo "Checking USER.md..."
if [ -f "USER.md" ]; then
    USER_LINES=$(grep -v "^#\|^$\|^\[.*\]\|^-\s*$" USER.md | wc -l)
    USER_HAS_NAME=$(grep -i "name:" USER.md | grep -v "\[.*name\]" | head -1)
    
    if [ "$USER_LINES" -gt 3 ] && [ -n "$USER_HAS_NAME" ]; then
        USER_FILLED="yes"
        pass "USER.md has content ($USER_LINES lines)"
    else
        USER_FILLED="no"
        echo "   USER.md appears to be template only"
    fi
else
    USER_FILLED="no"
    echo "   USER.md not found"
fi

# Check TOOLS.md for Solvr
echo "Checking Solvr registration..."
if [ -f "TOOLS.md" ]; then
    if grep -qi "solvr_[a-zA-Z0-9]" TOOLS.md; then
        SOLVR_REGISTERED="yes"
        pass "Solvr API key found in TOOLS.md"
    else
        SOLVR_REGISTERED="no"
        echo "   No Solvr API key in TOOLS.md"
    fi
else
    SOLVR_REGISTERED="no"
    echo "   TOOLS.md not found"
fi

# Check HEARTBEAT.md
echo "Checking HEARTBEAT.md..."
if [ -f "HEARTBEAT.md" ]; then
    HEARTBEAT_LINES=$(wc -l < HEARTBEAT.md)
    if [ "$HEARTBEAT_LINES" -gt 10 ]; then
        pass "HEARTBEAT.md configured ($HEARTBEAT_LINES lines)"
    else
        echo "   HEARTBEAT.md is minimal"
    fi
else
    echo "   HEARTBEAT.md not found"
fi

echo ""
echo "================================"
echo "Consistency Analysis"
echo "================================"

# Check: files filled but onboarding not complete?
if [ "$ONBOARD_STATUS" = "not_started" ] || [ "$ONBOARD_STATUS" = "not started" ]; then
    if [ "$SOUL_FILLED" = "yes" ] || [ "$USER_FILLED" = "yes" ]; then
        fail "INCONSISTENT: Files are filled but onboarding shows 'not_started'"
        echo ""
        echo "   Files were populated manually, bypassing onboarding."
        echo "   Options:"
        echo "   1. Run: Tell agent 'let's do onboarding' to do it properly"
        echo "   2. Sync: Update ONBOARDING.md status to 'complete' manually"
        echo "   3. Reset: Clear SOUL.md/USER.md and start fresh"
    fi
fi

if [ "$ONBOARD_STATUS" = "complete" ]; then
    if [ "$SOUL_FILLED" = "no" ] || [ "$USER_FILLED" = "no" ]; then
        fail "INCONSISTENT: Onboarding 'complete' but files are empty"
    else
        pass "Onboarding complete and files populated"
    fi
fi

if [ "$ONBOARD_STATUS" = "in_progress" ]; then
    info "Onboarding in progress — continue when ready"
fi

# Tech level specific checks
echo ""
if [ "$TECH_LEVEL" = "not_set" ]; then
    if [ "$ONBOARD_STATUS" = "in_progress" ] || [ "$ONBOARD_STATUS" = "complete" ]; then
        warn "TechLevel not set — may be using old onboarding format"
        echo "   New onboarding asks tech level first (simple/intermediate/advanced)"
    fi
fi

# Solvr check based on tech level
if [ "$EXPECTS_SOLVR" = "yes" ] && [ "$SOLVR_REGISTERED" = "no" ]; then
    warn "Solvr expected for $TECH_LEVEL level but not registered"
    echo "   Run: Tell agent to register on Solvr"
elif [ "$EXPECTS_SOLVR" = "no" ] && [ "$SOLVR_REGISTERED" = "yes" ]; then
    pass "Solvr registered (user upgraded from simple level)"
elif [ "$SOLVR_REGISTERED" = "no" ] && [ "$TECH_LEVEL" != "simple" ]; then
    warn "Solvr not registered — agent can't access collective knowledge"
fi

echo ""
echo "================================"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}No consistency issues found${NC}"
else
    echo -e "${RED}$ISSUES consistency issue(s) found${NC}"
fi
echo ""
echo "Tech level: $TECH_LEVEL"
echo "Solvr: $SOLVR_REGISTERED"
echo "Files: SOUL=$SOUL_FILLED USER=$USER_FILLED"
