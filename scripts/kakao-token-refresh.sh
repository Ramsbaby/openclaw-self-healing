#!/bin/bash

# Kakao Access Token Auto Refresh
# Refreshes access token using refresh token before 6-hour expiry

set -e

CONFIG_PATH="$HOME/.openclaw/openclaw.json"

# Load from config
REST_API_KEY=$(jq -r '.env.vars.KAKAO_REST_API_KEY // empty' "$CONFIG_PATH")
CLIENT_SECRET=$(jq -r '.env.vars.KAKAO_CLIENT_SECRET // empty' "$CONFIG_PATH")

if [ -z "$REST_API_KEY" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "❌ KAKAO_REST_API_KEY or KAKAO_CLIENT_SECRET not found in config"
  # Send error to memory for cron to pick up (daily log file)
  LOG_FILE="$HOME/openclaw/memory/kakao-token-errors-$(date +%Y-%m-%d).log"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] KAKAO_TOKEN_REFRESH_FAILED: Config missing" >> "$LOG_FILE"
  exit 1
fi

# Read current refresh token
REFRESH_TOKEN=$(jq -r '.env.vars.KAKAO_REFRESH_TOKEN // empty' "$CONFIG_PATH")

if [ -z "$REFRESH_TOKEN" ]; then
  echo "❌ KAKAO_REFRESH_TOKEN not found in config"
  exit 1
fi

echo "🔄 Refreshing Kakao access token..."

# Request new tokens
RESPONSE=$(curl -s -X POST "https://kauth.kakao.com/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded;charset=utf-8" \
  -d "grant_type=refresh_token" \
  -d "client_id=$REST_API_KEY" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "refresh_token=$REFRESH_TOKEN")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
  echo "❌ Token refresh failed:"
  echo "$RESPONSE" | jq '.'
  # Log error (daily log file)
  ERROR_DESC=$(echo "$RESPONSE" | jq -r '.error_description // .error')
  LOG_FILE="$HOME/openclaw/memory/kakao-token-errors-$(date +%Y-%m-%d).log"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] KAKAO_TOKEN_REFRESH_FAILED: $ERROR_DESC" >> "$LOG_FILE"
  exit 1
fi

# Extract tokens
NEW_ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
NEW_REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token // empty')
EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.expires_in')
REFRESH_EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.refresh_token_expires_in // empty')

echo "✅ New access token received (expires in ${EXPIRES_IN}s)"

# Calculate expiry timestamps (portable: works on macOS and Linux)
EXPIRES_AT=$(node -e "console.log(new Date(Date.now() + $EXPIRES_IN * 1000).toISOString())")

# Update config
TMP_CONFIG=$(mktemp)
jq --arg access "$NEW_ACCESS_TOKEN" \
   --arg expires "$EXPIRES_AT" \
   '.env.vars.KAKAO_ACCESS_TOKEN = $access | .env.vars.KAKAO_TOKEN_EXPIRES_AT = $expires' \
   "$CONFIG_PATH" > "$TMP_CONFIG"

# Update refresh token if new one provided
if [ -n "$NEW_REFRESH_TOKEN" ] && [ "$NEW_REFRESH_TOKEN" != "null" ]; then
  echo "✅ New refresh token received (expires in ${REFRESH_EXPIRES_IN}s)"
  REFRESH_EXPIRES_AT=$(node -e "console.log(new Date(Date.now() + $REFRESH_EXPIRES_IN * 1000).toISOString())")
  jq --arg refresh "$NEW_REFRESH_TOKEN" \
     --arg refresh_expires "$REFRESH_EXPIRES_AT" \
     '.env.vars.KAKAO_REFRESH_TOKEN = $refresh | .env.vars.KAKAO_REFRESH_TOKEN_EXPIRES_AT = $refresh_expires' \
     "$TMP_CONFIG" > "${TMP_CONFIG}.2"
  mv "${TMP_CONFIG}.2" "$TMP_CONFIG"
fi

mv "$TMP_CONFIG" "$CONFIG_PATH"

echo "💾 Tokens saved to config"
echo "✅ Done! (no restart needed - runtime config reload)"
