#!/usr/bin/env bash
# scripts/lib/notify.sh — unified notification dispatcher
#
# Supports Discord, Slack, and Telegram out of the box.
# Auto-detects the channel from available environment variables.
#
# Usage:
#   source scripts/lib/notify.sh
#   send_notification "Title" "Message body" "info|warning|error"
#
# Environment variables (set at least one group):
#   NOTIFICATION_CHANNEL    — force channel: "discord" | "slack" | "telegram"
#   DISCORD_WEBHOOK_URL     — Discord incoming webhook URL
#   SLACK_WEBHOOK_URL       — Slack incoming webhook URL
#   TELEGRAM_BOT_TOKEN      — Telegram bot token
#   TELEGRAM_CHAT_ID        — Telegram chat/channel ID

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

send_notification() {
    local title="${1:-Notification}"
    local message="${2:-}"
    local level="${3:-info}"
    local channel="${NOTIFICATION_CHANNEL:-}"

    # Auto-detect channel from available env vars when not explicitly set
    if [[ -z "$channel" ]]; then
        if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
            channel="discord"
        elif [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
            channel="slack"
        elif [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
            channel="telegram"
        else
            echo "[notify] No notification channel configured" >&2
            return 0
        fi
    fi

    case "$channel" in
        discord)  _notify_discord  "$title" "$message" "$level" ;;
        slack)    _notify_slack    "$title" "$message" "$level" ;;
        telegram) _notify_telegram "$title" "$message" ;;
        *)
            echo "[notify] Unknown channel: $channel" >&2
            return 0
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Private: Discord
# ---------------------------------------------------------------------------

_notify_discord() {
    local title="$1"
    local message="$2"
    local level="$3"
    local color

    case "$level" in
        error)   color=15158332 ;;  # red    #E74C3C
        warning) color=16776960 ;;  # yellow #FFFF00
        *)       color=3066993  ;;  # green  #2ECC71
    esac

    if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
        echo "[notify] DISCORD_WEBHOOK_URL is not set" >&2
        return 0
    fi

    # Escape double-quotes in user-supplied strings to keep JSON valid
    local safe_title safe_message
    safe_title="${title//\"/\\\"}"
    safe_message="${message//\"/\\\"}"

    local payload
    payload=$(printf '{"embeds":[{"title":"%s","description":"%s","color":%d}]}' \
        "$safe_title" "$safe_message" "$color")

    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "${DISCORD_WEBHOOK_URL}" >/dev/null || true
}

# ---------------------------------------------------------------------------
# Private: Slack
# ---------------------------------------------------------------------------

_notify_slack() {
    local title="$1"
    local message="$2"
    local level="$3"
    local emoji

    case "$level" in
        error)   emoji=":red_circle:" ;;
        warning) emoji=":warning:" ;;
        *)       emoji=":white_check_mark:" ;;
    esac

    if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
        echo "[notify] SLACK_WEBHOOK_URL is not set" >&2
        return 0
    fi

    local safe_title safe_message
    safe_title="${title//\"/\\\"}"
    safe_message="${message//\"/\\\"}"

    local payload
    payload=$(printf '{"text":"%s *%s*\n%s"}' "$emoji" "$safe_title" "$safe_message")

    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "${SLACK_WEBHOOK_URL}" >/dev/null || true
}

# ---------------------------------------------------------------------------
# Private: Telegram
# ---------------------------------------------------------------------------

_notify_telegram() {
    local title="$1"
    local message="$2"

    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
        echo "[notify] TELEGRAM_BOT_TOKEN is not set" >&2
        return 0
    fi

    if [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        echo "[notify] TELEGRAM_CHAT_ID is not set" >&2
        return 0
    fi

    local text="*${title}*\n${message}"

    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${text}" \
        -d "parse_mode=Markdown" \
        >/dev/null || true
}
