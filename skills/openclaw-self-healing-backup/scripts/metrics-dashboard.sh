#!/bin/bash
# OpenClaw Self-Healing Metrics Dashboard
# Visualize recovery statistics

set -euo pipefail

LOG_DIR="${OPENCLAW_MEMORY_DIR:-$HOME/openclaw/memory}"
METRICS_FILE="$LOG_DIR/.emergency-recovery-metrics.json"

if [ ! -f "$METRICS_FILE" ]; then
  echo "❌ No metrics file found: $METRICS_FILE"
  echo "Run at least one emergency recovery first."
  exit 1
fi

# Parse metrics using jq
if ! command -v jq &> /dev/null; then
  echo "⚠️  jq not installed. Installing via Homebrew..."
  brew install jq
fi

echo "📊 OpenClaw Self-Healing Metrics Dashboard"
echo "==========================================="
echo ""

# Total recovery attempts
total=$(jq -s 'length' "$METRICS_FILE")
echo "🔢 Total Recovery Attempts: $total"
echo ""

# Success rate
success_count=$(jq -s '[.[] | select(.result == "true")] | length' "$METRICS_FILE")
failure_count=$(jq -s '[.[] | select(.result == "false")] | length' "$METRICS_FILE")
success_rate=$(echo "scale=1; $success_count * 100 / $total" | bc 2>/dev/null || echo "0")

echo "✅ Successful Recoveries: $success_count / $total ($success_rate%)"
echo "❌ Failed Recoveries: $failure_count / $total"
echo ""

# Average recovery time
avg_duration=$(jq -s '[.[] | .duration] | add / length | floor' "$METRICS_FILE")
echo "⏱️  Average Recovery Time: ${avg_duration}s"
echo ""

# Recent recoveries (last 5)
echo "📋 Recent Recoveries (last 5):"
jq -s 'sort_by(.timestamp) | reverse | .[:5] | .[] | "  - \((.timestamp | strftime("%Y-%m-%d %H:%M"))) | Result: \(.result) | Duration: \(.duration)s | Symptom: \(.symptom // "unknown")"' -r "$METRICS_FILE"
echo ""

# Top symptoms (if available)
echo "🔍 Top Failure Symptoms:"
jq -s '[.[] | select(.symptom != "unknown") | .symptom] | group_by(.) | map({symptom: .[0], count: length}) | sort_by(.count) | reverse | .[:3] | .[] | "  - \(.symptom): \(.count) occurrences"' -r "$METRICS_FILE" || echo "  (No symptom data yet)"
echo ""

# Top root causes (if available)
echo "🎯 Top Root Causes:"
jq -s '[.[] | select(.root_cause != "unknown") | .root_cause] | group_by(.) | map({cause: .[0], count: length}) | sort_by(.count) | reverse | .[:3] | .[] | "  - \(.cause): \(.count) occurrences"' -r "$METRICS_FILE" || echo "  (No root cause data yet)"
echo ""

# Trend (last 7 days)
echo "📈 7-Day Trend:"
jq -s --arg week_ago "$(date -v-7d +%s 2>/dev/null || date -d '7 days ago' +%s)" '[.[] | select(.timestamp > ($week_ago | tonumber))] | length' "$METRICS_FILE" | {
  read -r count
  echo "  Last 7 days: $count attempts"
}
echo ""

echo "==========================================="
echo "💡 Tip: Review recovery-learnings.md for detailed insights"
echo "📁 Metrics file: $METRICS_FILE"
