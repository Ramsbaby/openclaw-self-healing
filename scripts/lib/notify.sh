#!/bin/bash
# OpenClaw Self-Healing Notification Library
# Multi-channel notification support (Discord, Telegram)

# ============================================
# Configuration (from environment)
# ============================================
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
NOTIFICATION_CHANNEL="${NOTIFICATION_CHANNEL:-discord}"  # discord|telegram|all

# ============================================
# Discord Notification
# ============================================
send_discord_notification() {
  local message="$1"
  
  if [ -z "$DISCORD_WEBHOOK" ]; then
    log "⚠️ Discord webhook not configured, skipping Discord notification"
    return 1
  fi
  
  local response_code
  response_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$message\"}" \
    2>&1 || echo "000")
  
  if [ "$response_code" = "200" ] || [ "$response_code" = "204" ]; then
    log "✅ Discord notification sent (HTTP $response_code)"
    return 0
  else
    log "⚠️ Discord notification failed (HTTP $response_code)"
    return 1
  fi
}

# ============================================
# Telegram Notification
# ============================================
send_telegram_notification() {
  local message="$1"
  
  if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    log "⚠️ Telegram credentials not configured, skipping Telegram notification"
    return 1
  fi
  
  # Convert Discord-style markdown to Telegram format
  # - **bold** → *bold*
  # - \`code\` → `code` (same)
  # - \\n → actual newlines
  local telegram_message
  telegram_message=$(echo -e "$message" | sed 's/\*\*/*/g')
  
  # Telegram Bot API endpoint
  local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
  
  # Send message with Markdown formatting
  local response
  response=$(curl -s -X POST "$api_url" \
    -H "Content-Type: application/json" \
    -d "{
      \"chat_id\": \"$TELEGRAM_CHAT_ID\",
      \"text\": \"$telegram_message\",
      \"parse_mode\": \"Markdown\",
      \"disable_notification\": false
    }" 2>&1)
  
  # Check if response contains "ok":true
  if echo "$response" | grep -q '"ok":true'; then
    log "✅ Telegram notification sent"
    return 0
  else
    # Extract error description if available
    local error_msg
    error_msg=$(echo "$response" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$error_msg" ]; then
      log "⚠️ Telegram notification failed: $error_msg"
    else
      log "⚠️ Telegram notification failed: $response"
    fi
    return 1
  fi
}

# ============================================
# Multi-Channel Dispatcher
# ============================================
send_notification() {
  local message="$1"
  local success=false
  
  case "$NOTIFICATION_CHANNEL" in
    discord)
      send_discord_notification "$message" && success=true
      ;;
    
    telegram)
      send_telegram_notification "$message" && success=true
      ;;
    
    all)
      # Send to both channels (don't fail if one fails)
      send_discord_notification "$message" && success=true
      send_telegram_notification "$message" && success=true
      ;;
    
    *)
      log "⚠️ Unknown notification channel: $NOTIFICATION_CHANNEL (supported: discord, telegram, all)"
      log "⚠️ Falling back to Discord only"
      send_discord_notification "$message" && success=true
      ;;
  esac
  
  if [ "$success" = true ]; then
    return 0
  else
    return 1
  fi
}
