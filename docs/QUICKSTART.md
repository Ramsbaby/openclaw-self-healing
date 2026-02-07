# Quick Start Guide

> **Get OpenClaw Self-Healing running in 5 minutes.**

---

## Prerequisites Check

Before starting, verify you have:

```bash
# Check macOS version (10.14+ required)
sw_vers

# Check OpenClaw is installed
openclaw version

# Check Homebrew is installed
brew --version

# If missing:
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## Step 1: Install Dependencies (2 minutes)

### Install tmux

```bash
brew install tmux

# Verify
tmux -V
# Expected: tmux 3.x or later
```

### Install Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code

# Verify
claude --version
# Expected: @anthropic-ai/claude-code 0.x.x

# Test Claude (optional)
claude
# Press Ctrl+C to exit
```

---

## Step 2: Download Scripts (1 minute)

### Option A: Git Clone (Recommended)

```bash
cd ~/openclaw
git clone https://github.com/ramsbaby/openclaw-self-healing.git
cd openclaw-self-healing
```

### Option B: Manual Download

1. Download ZIP from GitHub
2. Extract to `~/openclaw/openclaw-self-healing`
3. `cd ~/openclaw/openclaw-self-healing`

---

## Step 3: Configure Environment (1 minute)

### Copy environment template

```bash
cp .env.example ~/.openclaw/.env
```

### Edit environment file

```bash
# Open with your favorite editor
nano ~/.openclaw/.env
# or
code ~/.openclaw/.env
```

**Required changes:**

1. **Discord Webhook URL** (optional but recommended)
   - Go to Discord: Server Settings > Integrations > Webhooks
   - Create a webhook for your notification channel
   - Copy the webhook URL
   - Paste into `.env`:
     ```bash
     DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
     ```

2. **Other settings** (optional)
   - Most defaults are fine for typical setups
   - See `.env.example` for all options

### Save and exit

- **nano:** Ctrl+O, Enter, Ctrl+X
- **vim:** Esc, `:wq`, Enter
- **VS Code:** Cmd+S, Cmd+W

---

## Step 4: Install Scripts (30 seconds)

### Copy scripts to OpenClaw workspace

```bash
# Make scripts directory if it doesn't exist
mkdir -p ~/openclaw/scripts

# Copy scripts
cp scripts/*.sh ~/openclaw/scripts/

# Make executable
chmod +x ~/openclaw/scripts/*.sh

# Verify
ls -lh ~/openclaw/scripts/
# Should show: gateway-healthcheck.sh, emergency-recovery.sh, emergency-recovery-monitor.sh
```

---

## Step 5: Install LaunchAgent (30 seconds)

### Copy LaunchAgent plist

```bash
# Create LaunchAgents directory if needed
mkdir -p ~/Library/LaunchAgents

# Copy plist file
cp launchagent/com.openclaw.healthcheck.plist ~/Library/LaunchAgents/

# Load LaunchAgent
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

### Verify LaunchAgent

```bash
# Check if loaded
launchctl list | grep openclaw.healthcheck

# Expected output:
# -    0    com.openclaw.healthcheck
```

---

## Step 6: Add Cron Job (1 minute)

### Option A: OpenClaw CLI (Recommended)

```bash
# Add Emergency Recovery Monitor cron
openclaw cron add \
  --name "🚨 Emergency Recovery 실패 감지" \
  --schedule '*/5 * * * *' \
  --command 'bash ~/openclaw/scripts/emergency-recovery-monitor.sh' \
  --session isolated \
  --model claude-haiku-4-5
```

### Option B: Manual cron registration

1. Get your Discord channel ID:
   ```bash
   # In Discord: Enable Developer Mode (Settings > Advanced)
   # Right-click your notification channel > Copy ID
   ```

2. Add cron via OpenClaw config:
   ```bash
   nano ~/.openclaw/openclaw.json
   ```

3. Add to `crons` array:
   ```json
   {
     "name": "🚨 Emergency Recovery 실패 감지",
     "schedule": {
       "kind": "every",
       "everyMs": 300000
     },
     "payload": {
       "kind": "agentTurn",
       "message": "$(bash ~/openclaw/scripts/emergency-recovery-monitor.sh)"
     },
     "sessionTarget": "isolated",
     "enabled": true
   }
   ```

4. Restart Gateway:
   ```bash
   openclaw gateway restart
   ```

### Verify cron

```bash
# List crons
openclaw cron list | grep "Emergency Recovery"

# Should show: enabled: true
```

---

## Step 7: Verify Installation (30 seconds)

### Check all components

```bash
# 1. LaunchAgent status
launchctl list | grep openclaw.healthcheck
# Expected: -    0    com.openclaw.healthcheck

# 2. Health Check logs (should exist)
ls ~/openclaw/memory/healthcheck-*.log
# Expected: healthcheck-YYYY-MM-DD.log

# 3. Cron status
openclaw cron list | grep "Emergency Recovery"
# Expected: enabled: true

# 4. Scripts are executable
ls -lh ~/openclaw/scripts/*.sh
# Expected: -rwxr-xr-x (x = executable)
```

---

## Step 8: Test the System (Optional)

### Test Level 1: Watchdog

```bash
# Simulate Gateway crash
echo "Testing Level 1 Watchdog..."
kill -9 $(pgrep -f openclaw-gateway)

# Wait 3 minutes
echo "Waiting 180 seconds for watchdog recovery..."
sleep 180

# Check if recovered
curl -I http://localhost:18789/
# Expected: HTTP/1.1 200 OK
```

### Test Level 2: Health Check

```bash
# View Health Check logs in real-time
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log

# Health Check runs every 5 minutes
# Look for: "✅ Gateway healthy"
```

### Test Discord Notifications (if configured)

```bash
# Send test notification
bash -c '
source ~/.openclaw/.env
curl -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"✅ Self-Healing System test notification\"}"
'

# Check Discord channel for message
```

---

## Troubleshooting

### Issue: LaunchAgent won't load

**Error:** `Load failed: 5: Input/output error`

**Fix:**
```bash
# Unload first (if already loaded)
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist

# Fix permissions
chmod 644 ~/Library/LaunchAgents/com.openclaw.healthcheck.plist

# Reload
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

### Issue: Scripts not executable

**Error:** `Permission denied`

**Fix:**
```bash
chmod +x ~/openclaw/scripts/*.sh
```

### Issue: tmux not found

**Error:** `command not found: tmux`

**Fix:**
```bash
brew install tmux
```

### Issue: Claude CLI not found

**Error:** `command not found: claude`

**Fix:**
```bash
npm install -g @anthropic-ai/claude-code

# If npm not found, install Node.js:
brew install node
```

### Issue: Discord notifications not working

**Symptoms:** No messages in Discord channel

**Check:**
1. Webhook URL is correct in `~/.openclaw/.env`
2. Webhook is enabled in Discord server
3. Test webhook manually:
   ```bash
   source ~/.openclaw/.env
   curl -X POST "$DISCORD_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"content": "Test"}'
   ```

### Issue: Health Check logs empty

**Symptoms:** No logs in `~/openclaw/memory/healthcheck-*.log`

**Check:**
```bash
# Verify LaunchAgent is running
launchctl list | grep openclaw.healthcheck

# Check LaunchAgent logs
tail -f ~/Library/Logs/com.openclaw.healthcheck.log

# If missing, LaunchAgent hasn't run yet (runs every 5 min)
# Force run manually:
bash ~/openclaw/scripts/gateway-healthcheck.sh
```

---

## Next Steps

- **Read the docs:** [docs/self-healing-system.md](self-healing-system.md)
- **Customize settings:** Edit `~/.openclaw/.env`
- **Test Level 3:** Inject a config error and watch Claude fix it
- **Monitor logs:** `tail -f ~/openclaw/memory/*.log`

---

## Uninstall (if needed)

```bash
# 1. Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
rm ~/Library/LaunchAgents/com.openclaw.healthcheck.plist

# 2. Remove cron
openclaw cron list | grep "Emergency Recovery"
# Copy the ID, then:
openclaw cron remove <CRON_ID>

# 3. Remove scripts (optional)
rm ~/openclaw/scripts/gateway-healthcheck.sh
rm ~/openclaw/scripts/emergency-recovery.sh
rm ~/openclaw/scripts/emergency-recovery-monitor.sh

# 4. Remove environment file (optional)
rm ~/.openclaw/.env

# 5. Remove logs (optional)
rm ~/openclaw/memory/healthcheck-*.log
rm ~/openclaw/memory/emergency-recovery-*.log
rm ~/openclaw/memory/claude-session-*.log
```

---

<p align="center">
  <strong>Installation complete! 🎉</strong>
</p>

<p align="center">
  Your OpenClaw Gateway is now self-healing.<br>
  Sit back and let the AI handle the crashes.
</p>
