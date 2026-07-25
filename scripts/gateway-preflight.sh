#!/usr/bin/env bash
# gateway-preflight.sh — OpenClaw Gateway proactive config validation + AI auto-recovery wrapper
#
# Flow:
#   1. Validate gateway binary, .env keys, and JSON config files
#   2. On failure → spawn tmux 'openclaw-recovery' session with ANTHROPIC_API_KEY via -e flag
#                   → send Discord/ntfy alert
#                   → exponential backoff (30s → 90s → 180s) → exit 1 (launchd restarts)
#   3. On success → exec the gateway process (bash replaced by gateway; launchd tracks gateway PID)
#
# MAX_PREFLIGHT_ATTEMPTS=3 enforced via state file with 6-hour auto-reset.
#
# Differences from Jarvis bot-preflight.sh:
#   - OPENCLAW_HOME instead of BOT_HOME
#   - tmux session: 'openclaw-recovery' (matches emergency-recovery-v2.sh naming)
#   - Calls emergency-recovery-v2.sh instead of bot-heal.sh
#   - Checks openclaw.json in addition to .env

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
OPENCLAW_SCRIPT="${OPENCLAW_SCRIPT:-$(command -v openclaw 2>/dev/null || echo "/opt/homebrew/bin/openclaw")}"
ENV_FILE="$OPENCLAW_HOME/.env"
CONFIG_FILE="$OPENCLAW_HOME/openclaw.json"
LOG_DIR="$OPENCLAW_HOME/logs"
LOG_FILE="$LOG_DIR/preflight.log"
BACKUP_DIR="$OPENCLAW_HOME/state/config-backups"
STATE_DIR="$OPENCLAW_HOME/state"
HEAL_ATTEMPTS_FILE="$STATE_DIR/preflight-heal-attempts"
EMERGENCY_RECOVERY_SCRIPT="$HOME/.openclaw/skills/openclaw-self-healing/scripts/emergency-recovery-v2.sh"

MAX_PREFLIGHT_ATTEMPTS=3
BACKOFF_DELAYS=(30 90 180)

# Auto-reset heal counter after this many seconds of stability (6 hours)
HEAL_COUNTER_RESET_AFTER=21600

mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$STATE_DIR"

# ============================================================================
# Logging
# ============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [preflight] $*" | tee -a "$LOG_FILE"
}

# ============================================================================
# Alert helpers
# ============================================================================
send_discord_alert() {
    local msg="$1"
    local webhook=""
    if [[ -f "$ENV_FILE" ]]; then
        webhook=$(grep -E '^DISCORD_WEBHOOK_URL=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    fi
    if [[ -z "$webhook" ]]; then
        webhook="${DISCORD_WEBHOOK_URL:-}"
    fi
    if [[ -n "$webhook" ]]; then
        curl -sf --max-time 5 \
            -X POST "$webhook" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"$msg\"}" >/dev/null 2>&1 || true
    fi
}

send_ntfy_alert() {
    local msg="$1"
    local topic=""
    # Read ntfy topic from monitoring.json if it exists
    local monitoring_json="$OPENCLAW_HOME/monitoring.json"
    if [[ -f "$monitoring_json" ]] && command -v python3 &>/dev/null; then
        topic=$(python3 -c "import json; d=json.load(open('$monitoring_json')); print(d.get('ntfy',{}).get('topic',''))" 2>/dev/null || echo "")
    fi
    if [[ -z "$topic" ]]; then
        topic="${NTFY_TOPIC:-}"
    fi
    if [[ -n "$topic" ]]; then
        curl -sf --max-time 5 \
            -H "Title: OpenClaw Gateway Preflight Failed" \
            -H "Priority: urgent" \
            -H "Tags: x,robot" \
            -d "$msg" \
            "https://ntfy.sh/${topic}" >/dev/null 2>&1 || true
    fi
}

send_alert() {
    local msg="$1"
    send_discord_alert "🚨 **OpenClaw Preflight Failed**\\n\\n${msg}"
    send_ntfy_alert "$msg"
}

# ============================================================================
# Failure handler: spawn AI recovery session → backoff → exit 1
# ============================================================================
fail_and_heal() {
    local reason="$1"
    log "FAIL: $reason"

    # ── Read current attempt count ────────────────────────────────────────────
    local attempts=0
    if [[ -f "$HEAL_ATTEMPTS_FILE" ]]; then
        attempts=$(cat "$HEAL_ATTEMPTS_FILE" 2>/dev/null || echo 0)
    fi

    # ── Auto-reset counter if file is older than HEAL_COUNTER_RESET_AFTER ────
    if [[ -f "$HEAL_ATTEMPTS_FILE" ]]; then
        local last_mtime
        last_mtime=$(stat -f %m "$HEAL_ATTEMPTS_FILE" 2>/dev/null || echo 0)
        local age=$(( $(date +%s) - last_mtime ))
        if (( age > HEAL_COUNTER_RESET_AFTER )); then
            log "6h elapsed — resetting heal counter (was: ${attempts} attempts)"
            rm -f "$HEAL_ATTEMPTS_FILE"
            attempts=0
        fi
    fi

    # ── Max attempts exceeded: long sleep to avoid launchd spam ──────────────
    if (( attempts >= MAX_PREFLIGHT_ATTEMPTS )); then
        log "CRITICAL: Exceeded ${MAX_PREFLIGHT_ATTEMPTS} heal attempts — manual intervention required"
        send_alert "Preflight auto-heal limit reached (${MAX_PREFLIGHT_ATTEMPTS}x). Manual fix needed.\\nReason: ${reason}\\nLog: ${LOG_FILE}"
        log "Sleeping 300s to prevent launchd restart storm..."
        sleep 300
        exit 1
    fi

    echo $(( attempts + 1 )) > "$HEAL_ATTEMPTS_FILE"
    log "Heal attempt $(( attempts + 1 ))/${MAX_PREFLIGHT_ATTEMPTS}: ${reason}"

    # ── Spawn AI recovery session via tmux ───────────────────────────────────
    # IMPORTANT: Pass ANTHROPIC_API_KEY via -e flag.
    # tmux sessions spawned from launchd do NOT inherit launchd env vars,
    # so the API key must be forwarded explicitly.
    if command -v tmux &>/dev/null; then
        if tmux has-session -t openclaw-recovery 2>/dev/null; then
            log "Recovery session 'openclaw-recovery' already running — waiting for it to finish"
        else
            log "Spawning AI recovery tmux session: openclaw-recovery"
            if [[ -x "$EMERGENCY_RECOVERY_SCRIPT" ]]; then
                tmux new-session -d -s openclaw-recovery \
                    -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" \
                    -e "OPENCLAW_HOME=$OPENCLAW_HOME" \
                    -e "HOME=$HOME" \
                    -e "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" \
                    "bash '${EMERGENCY_RECOVERY_SCRIPT}'" \
                    2>/dev/null || log "WARN: Failed to spawn tmux recovery session"
            else
                # Fallback: open a claude interactive session directly
                tmux new-session -d -s openclaw-recovery \
                    -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" \
                    -e "OPENCLAW_HOME=$OPENCLAW_HOME" \
                    -e "HOME=$HOME" \
                    -e "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" \
                    "/opt/homebrew/bin/claude" \
                    2>/dev/null || log "WARN: Failed to spawn tmux claude session"
            fi
        fi
    else
        log "WARN: tmux not found — alert only, no AI recovery session"
    fi

    send_alert "Preflight validation failed. AI recovery session started.\\nReason: ${reason}\\nAttempt: $(( attempts + 1 ))/${MAX_PREFLIGHT_ATTEMPTS}\\nLog: ${LOG_FILE}"

    # ── Exponential backoff before exit 1 (launchd will restart us) ──────────
    local delay_idx=$(( attempts < ${#BACKOFF_DELAYS[@]} ? attempts : ${#BACKOFF_DELAYS[@]} - 1 ))
    local sleep_sec="${BACKOFF_DELAYS[$delay_idx]}"
    log "Waiting ${sleep_sec}s before exit 1 (attempt $(( attempts + 1 ))/${MAX_PREFLIGHT_ATTEMPTS})..."
    sleep "$sleep_sec"
    exit 1
}

# ============================================================================
# Main validation
# ============================================================================
log "=== Preflight validation started ==="

# Load .env early so subsequent checks can use exported vars
if [[ -f "$ENV_FILE" ]]; then
    set +u
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set -u
fi

# ── 1. Check openclaw binary / gateway entry point ───────────────────────────
# Determine the actual gateway start command.
# openclaw may be a CLI wrapper; we just need it to be executable.
GATEWAY_CMD="${OPENCLAW_SCRIPT}"
if [[ ! -x "$GATEWAY_CMD" ]]; then
    # Try common install locations
    for candidate in \
        "/opt/homebrew/bin/openclaw" \
        "/usr/local/bin/openclaw" \
        "$HOME/.openclaw/bin/openclaw" \
        "$HOME/.openclaw/gateway/index.js"
    do
        if [[ -x "$candidate" ]]; then
            GATEWAY_CMD="$candidate"
            break
        fi
    done
fi

if [[ ! -x "$GATEWAY_CMD" ]]; then
    fail_and_heal "Gateway binary not found or not executable. Tried: ${OPENCLAW_SCRIPT} and common paths."
fi
log "Gateway binary OK: $GATEWAY_CMD"

# ── 2. Check node binary (gateway is a Node.js process) ──────────────────────
NODE_BIN="${NODE_BIN:-$(command -v node 2>/dev/null || echo "/opt/homebrew/bin/node")}"
if [[ ! -x "$NODE_BIN" ]]; then
    fail_and_heal "node binary not found: ${NODE_BIN}"
fi
log "Node binary OK: $NODE_BIN ($($NODE_BIN --version 2>/dev/null || echo 'version unknown'))"

# ── 3. Check .env file exists ─────────────────────────────────────────────────
if [[ ! -f "$ENV_FILE" ]]; then
    fail_and_heal ".env missing: ${ENV_FILE} — create it with OPENCLAW_GATEWAY_TOKEN and other required keys"
fi
log ".env present: $ENV_FILE"

# ── 4. Check required .env keys are set and non-empty ────────────────────────
REQUIRED_ENV_KEYS=(
    OPENCLAW_GATEWAY_TOKEN   # Gateway authentication token
    ANTHROPIC_API_KEY        # Claude AI — required for Level 3 emergency recovery
)
MISSING_KEYS=()
for key in "${REQUIRED_ENV_KEYS[@]}"; do
    if ! grep -qE "^${key}=.+" "$ENV_FILE" 2>/dev/null; then
        MISSING_KEYS+=("$key")
    fi
done
if [[ ${#MISSING_KEYS[@]} -gt 0 ]]; then
    fail_and_heal ".env missing or empty keys: ${MISSING_KEYS[*]}"
fi
log ".env required keys present: ${REQUIRED_ENV_KEYS[*]}"

# ── 5. Validate JSON config files ─────────────────────────────────────────────
JSON_CONFIGS=()
if [[ -f "$CONFIG_FILE" ]]; then
    JSON_CONFIGS+=("$CONFIG_FILE")
fi
# Also check any additional JSON files in config dir
for extra_json in \
    "$OPENCLAW_HOME/config.json" \
    "$OPENCLAW_HOME/channels.json"
do
    if [[ -f "$extra_json" ]]; then
        JSON_CONFIGS+=("$extra_json")
    fi
done

for json_file in "${JSON_CONFIGS[@]}"; do
    if ! "$NODE_BIN" -e "JSON.parse(require('fs').readFileSync('${json_file}','utf8'))" 2>/dev/null; then
        fail_and_heal "JSON parse error: $(basename "${json_file}") — fix syntax before gateway can start"
    fi
    log "JSON valid: $(basename "${json_file}")"
done

# ── 6. Backup current valid configs (so recovery can restore known-good state) ─
log "Backing up valid configs..."
for json_file in "${JSON_CONFIGS[@]}"; do
    cp "$json_file" "$BACKUP_DIR/$(basename "${json_file}").backup"
done
if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "$BACKUP_DIR/.env.backup"
fi
log "Backups saved to: $BACKUP_DIR"

# ── 7. All checks passed → reset heal counter ────────────────────────────────
rm -f "$HEAL_ATTEMPTS_FILE"
log "All preflight checks passed — heal counter reset"

# ── 8. exec the gateway (replaces bash; launchd tracks the gateway PID) ──────
log "Preflight passed → starting gateway via exec"
log "=== Preflight complete ==="

# exec replaces this bash process so launchd KeepAlive tracks the gateway PID directly.
exec "$GATEWAY_CMD" gateway start
