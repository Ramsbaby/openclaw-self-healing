#!/usr/bin/env bash
# GitHub Notification Checker
# Returns JSON array of important notifications (mentions, assignments, review requests)

# 1. State management
STATE_FILE="$HOME/clawd/skills/github-watcher/.last_check"
if [ ! -f "$STATE_FILE" ]; then
  date -u -v-1H +%Y-%m-%dT%H:%M:%SZ > "$STATE_FILE" # Default to 1 hour ago
fi
LAST_CHECK=$(cat "$STATE_FILE")
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 2. Fetch notifications
# Filter reasons: mention, review_requested, author, assign, manual (skip subscribed noise)
NOTIFICATIONS=$(gh api notifications \
  --method GET \
  -f since="$LAST_CHECK" \
  -f all=false \
  --jq '[.[] | select(.reason == "mention" or .reason == "review_requested" or .reason == "assign" or .reason == "author")]')

# 3. Output logic
COUNT=$(echo "$NOTIFICATIONS" | jq 'length')

if [ "$COUNT" -gt 0 ]; then
  echo "$NOTIFICATIONS"
  # Update state only if we found something (to ensure we processed them)
  # Actually, agent logic will handle processing. We update time here to avoid loop if agent fails?
  # No, let's update time AFTER successful fetch.
  echo "$CURRENT_TIME" > "$STATE_FILE"
else
  echo "[]"
  echo "$CURRENT_TIME" > "$STATE_FILE"
fi
