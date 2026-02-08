#!/bin/bash
# Proactive Solvr Agent — Security Audit
# Run periodically to check for security issues

set +e  # Don't exit on error - complete all checks

echo "🔒 Proactive Solvr Agent — Security Audit"
echo "=========================================="
echo ""

ISSUES=0
WARNINGS=0

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

warn() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; ((WARNINGS++)); }
fail() { echo -e "${RED}❌ ISSUE: $1${NC}"; ((ISSUES++)); }
pass() { echo -e "${GREEN}✅ $1${NC}"; }

# 1. Check credential file permissions
echo "📁 Checking credential files..."
if [ -d ".credentials" ]; then
    for f in .credentials/*; do
        if [ -f "$f" ]; then
            perms=$(stat -f "%Lp" "$f" 2>/dev/null || stat -c "%a" "$f" 2>/dev/null)
            if [ "$perms" != "600" ]; then
                fail "$f has permissions $perms (should be 600)"
            else
                pass "$f permissions OK (600)"
            fi
        fi
    done
else
    echo "   No .credentials directory found"
fi
echo ""

# 2. Check for exposed secrets in tracked files
echo "🔍 Scanning for exposed secrets..."
SECRET_PATTERNS="(api[_-]?key|apikey|secret|password|token|solvr_).*[=:].{10,}"
for f in $(ls *.md *.json *.yaml *.yml .env* 2>/dev/null || true); do
    if [ -f "$f" ]; then
        matches=$(grep -iE "$SECRET_PATTERNS" "$f" 2>/dev/null | grep -v "example\|template\|placeholder\|your-\|<\|TODO\|YOUR_" || true)
        if [ -n "$matches" ]; then
            warn "Possible secret in $f - review manually"
        fi
    fi
done
pass "Secret scan complete"
echo ""

# 3. Check AGENTS.md for security rules
echo "📋 Checking AGENTS.md for security rules..."
if [ -f "AGENTS.md" ]; then
    if grep -qi "injection\|external content\|never execute" "AGENTS.md"; then
        pass "AGENTS.md contains injection defense rules"
    else
        warn "AGENTS.md may be missing prompt injection defense"
    fi
    
    if grep -qi "deletion\|confirm.*delet\|ask first" "AGENTS.md"; then
        pass "AGENTS.md contains deletion confirmation rules"
    else
        warn "AGENTS.md may be missing deletion confirmation rules"
    fi
else
    warn "No AGENTS.md found"
fi
echo ""

# 4. Check Solvr configuration
echo "🌐 Checking Solvr configuration..."
if [ -f "TOOLS.md" ]; then
    if grep -qi "solvr\|SOLVR_API_KEY" "TOOLS.md"; then
        pass "Solvr configuration found in TOOLS.md"
        # Check it's not the placeholder
        if grep -q "YOUR_SOLVR_API_KEY\|your-api-key" "TOOLS.md"; then
            warn "Solvr API key may be placeholder - check TOOLS.md"
        fi
    else
        echo "   No Solvr configuration in TOOLS.md (optional)"
    fi
else
    warn "No TOOLS.md found"
fi
echo ""

# 5. Check gateway configuration (OpenClaw)
echo "🚪 Checking gateway configuration..."
CONFIG_DIRS=("$HOME/.clawdbot" "$HOME/.openclaw")
for config_dir in "${CONFIG_DIRS[@]}"; do
    config_file="$config_dir/config.json"
    if [ -f "$config_file" ]; then
        if grep -q '"bind".*"loopback"' "$config_file"; then
            pass "Gateway bound to loopback"
        else
            warn "Gateway may not be bound to loopback"
        fi
        break
    fi
done
echo ""

# 6. Check .gitignore
echo "📄 Checking .gitignore..."
if [ -f ".gitignore" ]; then
    if grep -q "\.credentials" ".gitignore"; then
        pass ".credentials is gitignored"
    else
        fail ".credentials is NOT in .gitignore"
    fi
    
    if grep -q "\.env" ".gitignore"; then
        pass ".env files are gitignored"
    else
        warn ".env files may not be gitignored"
    fi
    
    if grep -q "TOOLS\.md" ".gitignore" || grep -q "\*\.md" ".gitignore"; then
        echo "   Note: TOOLS.md may be gitignored (verify credentials not exposed)"
    fi
else
    warn "No .gitignore found"
fi
echo ""

# 7. Check ONBOARDING.md consistency
echo "📝 Checking onboarding consistency..."
if [ -f "ONBOARDING.md" ]; then
    ONBOARD_STATUS=$(grep -i "state:" ONBOARDING.md | head -1 | tr -d '*' | tr '[:upper:]' '[:lower:]')
    
    if echo "$ONBOARD_STATUS" | grep -qi "complete"; then
        pass "Onboarding complete"
    elif echo "$ONBOARD_STATUS" | grep -qi "in_progress"; then
        echo "   Onboarding in progress"
    else
        # Check for inconsistency: files filled but onboarding not started
        SOUL_FILLED=$([ -f "SOUL.md" ] && grep -cv "^#\|^$\|^\[" SOUL.md 2>/dev/null || echo 0)
        USER_FILLED=$([ -f "USER.md" ] && grep -cv "^#\|^$\|^\[" USER.md 2>/dev/null || echo 0)
        
        if [ "$SOUL_FILLED" -gt 5 ] || [ "$USER_FILLED" -gt 3 ]; then
            fail "INCONSISTENT: Files filled but onboarding 'not_started' — was bypassed"
        else
            echo "   Onboarding not started"
        fi
    fi
else
    echo "   No ONBOARDING.md found"
fi
echo ""

# Summary
echo "=========================================="
echo "📊 Summary"
echo "=========================================="
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warning(s), 0 issues${NC}"
else
    echo -e "${RED}$ISSUES issue(s), $WARNINGS warning(s)${NC}"
fi
echo ""
echo "Run this audit periodically during heartbeats."
