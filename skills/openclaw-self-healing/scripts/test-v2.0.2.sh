#!/bin/bash
# v2.0.2 Hotfix Verification Script
# Tests emergency-recovery-monitor.sh stdout delivery

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LOG_DIR="/tmp/openclaw-test-$$"
TEST_ALERT_SENT="$TEST_LOG_DIR/.emergency-alert-sent"

# Cleanup
cleanup() {
    rm -rf "$TEST_LOG_DIR"
}
trap cleanup EXIT

# Setup
mkdir -p "$TEST_LOG_DIR"

echo "========================================="
echo "v2.0.2 Hotfix Verification"
echo "========================================="
echo ""

# Test 1: Create emergency recovery failure log
echo "Test 1: Creating test emergency recovery log..."
cat > "$TEST_LOG_DIR/emergency-recovery-$(date +%Y%m%d-%H%M%S).log" << 'EOF'
[2026-02-08 11:38:10] === Emergency Recovery Started ===
[2026-02-08 11:38:10] ❌ Missing dependencies: claude
[2026-02-08 11:38:10] === MANUAL INTERVENTION REQUIRED ===
EOF

# Test 2: Run monitor (should output alert to stdout)
echo "Test 2: Running emergency-recovery-monitor.sh..."
echo ""

OUTPUT=$(OPENCLAW_MEMORY_DIR="$TEST_LOG_DIR" bash "$SCRIPT_DIR/emergency-recovery-monitor.sh" 2>&1)

# Test 3: Verify stdout contains alert message
echo "Test 3: Verifying stdout output..."
if echo "$OUTPUT" | grep -q "🚨 \*\*긴급: OpenClaw 자가복구 실패\*\*"; then
    echo "✅ Alert message found in stdout"
else
    echo "❌ Alert message NOT found in stdout"
    echo "Output was:"
    echo "$OUTPUT"
    exit 1
fi

# Test 4: Verify "Alert sent to stdout" log
if echo "$OUTPUT" | grep -q "Alert sent to stdout"; then
    echo "✅ Confirmation log found"
else
    echo "❌ Confirmation log NOT found"
    exit 1
fi

# Test 5: Verify no HTTP error (webhook removed)
if echo "$OUTPUT" | grep -q "HTTP 404\|HTTP 000\|Discord notification failed"; then
    echo "❌ HTTP error found (webhook not removed properly)"
    echo "$OUTPUT"
    exit 1
else
    echo "✅ No HTTP errors (webhook successfully removed)"
fi

# Test 6: Run again (should skip - alert already sent)
echo "Test 6: Running again (should detect duplicate)..."
OUTPUT2=$(OPENCLAW_MEMORY_DIR="$TEST_LOG_DIR" bash "$SCRIPT_DIR/emergency-recovery-monitor.sh" 2>&1)

if echo "$OUTPUT2" | grep -q "Alert already sent"; then
    echo "✅ Duplicate detection working"
else
    echo "❌ Duplicate detection failed"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ All tests passed!"
echo "========================================="
echo ""
echo "v2.0.2 hotfix verified:"
echo "  - Discord webhook removed"
echo "  - Stdout delivery working"
echo "  - No HTTP errors"
echo "  - Duplicate detection working"
echo ""
echo "Ready for release."
