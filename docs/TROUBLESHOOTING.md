# Troubleshooting Guide

> **Common issues and solutions for OpenClaw Self-Healing System**

---

## 🔍 Diagnostic Commands

Before diving into specific issues, run these diagnostic commands:

```bash
# 1. Check LaunchAgent status
launchctl list | grep openclaw

# 2. Check Health Check logs
tail -50 ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log

# 3. Check Emergency Recovery logs
ls -lt ~/openclaw/memory/emergency-recovery-*.log | head -5

# 4. Check Gateway status
openclaw status

# 5. Check cron jobs
openclaw cron list | grep -i "emergency\|health"

# 6. Check script permissions
ls -lh ~/openclaw/scripts/*.sh
```

---

## 🚨 Level 1: Watchdog Issues

### Issue: Watchdog not restarting Gateway

**Symptoms:**
- Gateway crashes but doesn't restart
- No automatic recovery after 3 minutes

**Diagnosis:**
```bash
# Check if Watchdog LaunchAgent is loaded
launchctl list | grep openclaw.watchdog

# Expected output:
# -    0    ai.openclaw.watchdog
```

**Solution 1: Watchdog not loaded**
```bash
# Check if plist exists
ls ~/Library/LaunchAgents/ai.openclaw.watchdog.plist

# If missing, reinstall OpenClaw:
npm install -g openclaw
openclaw onboard --install-daemon
```

**Solution 2: Watchdog disabled**
```bash
# Reload Watchdog
launchctl unload ~/Library/LaunchAgents/ai.openclaw.watchdog.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.watchdog.plist
```

---

## 🏥 Level 2: Health Check Issues

### Issue: Health Check not running

**Symptoms:**
- No `healthcheck-*.log` files in `~/openclaw/memory/`
- LaunchAgent listed but no activity

**Diagnosis:**
```bash
# Check LaunchAgent status
launchctl list | grep openclaw.healthcheck

# Check LaunchAgent logs
tail -f ~/Library/Logs/com.openclaw.healthcheck.log
```

**Solution 1: LaunchAgent not loaded**
```bash
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

**Solution 2: Script path wrong**
```bash
# Check plist file
cat ~/Library/LaunchAgents/com.openclaw.healthcheck.plist | grep ProgramArguments -A 2

# Should point to: ~/openclaw/scripts/gateway-healthcheck.sh
# If wrong, edit plist:
nano ~/Library/LaunchAgents/com.openclaw.healthcheck.plist

# Reload after edit:
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

**Solution 3: Script not executable**
```bash
chmod +x ~/openclaw/scripts/gateway-healthcheck.sh
```

**Solution 4: Run manually to test**
```bash
bash ~/openclaw/scripts/gateway-healthcheck.sh

# Check for errors in output
```

---

### Issue: Health Check false positives

**Symptoms:**
- Health Check reports failure but Gateway is running fine
- Unnecessary restarts

**Diagnosis:**
```bash
# Check Gateway URL
curl -I http://localhost:18789/

# Check environment variable
source ~/.openclaw/.env
echo $OPENCLAW_GATEWAY_URL
```

**Solution: Wrong Gateway URL**
```bash
# Edit .env
nano ~/.openclaw/.env

# Set correct URL:
OPENCLAW_GATEWAY_URL="http://localhost:18789/"

# Reload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

---

### Issue: Health Check restarts too aggressively

**Symptoms:**
- Gateway restarts multiple times per hour
- Unstable system

**Diagnosis:**
```bash
# Check retry settings
source ~/.openclaw/.env
echo "Max retries: ${HEALTH_CHECK_MAX_RETRIES:-3}"
echo "Retry delay: ${HEALTH_CHECK_RETRY_DELAY:-30}s"
```

**Solution: Increase thresholds**
```bash
# Edit .env
nano ~/.openclaw/.env

# Add/modify:
HEALTH_CHECK_MAX_RETRIES=5
HEALTH_CHECK_RETRY_DELAY=60
HEALTH_CHECK_ESCALATION_WAIT=600

# Reload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

---

## 🧠 Level 3: Claude Recovery Issues

### Issue: Claude CLI not found

**Symptoms:**
- Emergency Recovery logs show: `❌ Missing dependencies: claude`
- Level 3 skips to Level 4

**Diagnosis:**
```bash
# Check Claude installation
which claude
claude --version
```

**Solution: Install Claude CLI**
```bash
npm install -g @anthropic-ai/claude-code

# Verify
claude --version
```

---

### Issue: Claude session fails to start

**Symptoms:**
- Emergency Recovery logs show: `Starting Claude Code session...`
- Then: `⚠️ Claude workspace trust prompt not detected`

**Diagnosis:**
```bash
# Check tmux
which tmux
tmux -V

# Test Claude manually
claude
# Does it prompt "trust this workspace"?
```

**Solution 1: tmux not installed**
```bash
brew install tmux
```

**Solution 2: Claude workspace already trusted**
```bash
# This is actually OK — script proceeds anyway
# Check recovery logs for actual failure reason
tail -50 ~/openclaw/memory/emergency-recovery-*.log
```

---

### Issue: Claude API quota exceeded

**Symptoms:**
- Emergency Recovery logs show: `⚠️ Claude API rate limited or quota exceeded`
- Level 3 fails immediately

**Diagnosis:**
```bash
# Check Claude usage
claude
# Type: /usage
# Check remaining quota
```

**Solution: Wait for quota reset**
```bash
# Claude API resets every 5 hours
# Check exact reset time in Claude CLI: /usage

# Meanwhile, system escalates to Level 4 (human alert)
```

**Workaround: Increase timeout for next attempt**
```bash
# Edit .env
nano ~/.openclaw/.env

# Increase timeout:
EMERGENCY_RECOVERY_TIMEOUT=3600  # 1 hour instead of 30 min
```

---

### Issue: Claude recovery times out

**Symptoms:**
- Emergency Recovery runs for 30 minutes
- Gateway still unhealthy
- No clear failure reason in logs

**Diagnosis:**
```bash
# Check Claude session log
tail -200 ~/openclaw/memory/claude-session-*.log

# Look for:
# - Errors executing commands
# - Stuck waiting for input
# - Network issues
```

**Solution 1: Increase timeout**
```bash
# Edit .env
nano ~/.openclaw/.env

# Increase timeout:
EMERGENCY_RECOVERY_TIMEOUT=3600  # 1 hour
```

**Solution 2: Check manual recovery**
```bash
# What would you do manually?
openclaw status
tail -100 ~/.openclaw/logs/gateway.log

# Apply the fix yourself, then analyze why Claude couldn't
```

---

## 🚨 Level 4: Discord Notification Issues

### Issue: No Discord notifications

**Symptoms:**
- Level 4 should trigger but no messages in Discord
- Emergency Recovery Monitor cron runs but silent

**Diagnosis:**
```bash
# Check webhook URL
source ~/.openclaw/.env
echo $DISCORD_WEBHOOK_URL

# Test webhook manually
curl -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test notification"}'
```

**Solution 1: Webhook URL not set**
```bash
# Edit .env
nano ~/.openclaw/.env

# Add:
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
```

**Solution 2: Webhook URL invalid**
```bash
# Get new webhook from Discord:
# Server Settings > Integrations > Webhooks > New Webhook

# Copy URL and update .env
nano ~/.openclaw/.env
```

**Solution 3: Network issues**
```bash
# Test internet connectivity
ping -c 3 discord.com

# Test DNS resolution
nslookup discord.com

# If behind proxy, check proxy settings
```

---

### Issue: Duplicate Discord notifications

**Symptoms:**
- Same alert sent multiple times
- Alert flood in Discord channel

**Diagnosis:**
```bash
# Check alert tracking file
cat ~/openclaw/memory/.emergency-alert-sent

# Check Monitor cron frequency
openclaw cron list | grep "Emergency Recovery"
```

**Solution: Alert file corrupted**
```bash
# Remove alert tracking file
rm ~/openclaw/memory/.emergency-alert-sent

# Next alert will reset tracking
```

---

## 🔧 General Issues

### Issue: Logs filling up disk

**Symptoms:**
- `~/openclaw/memory/` grows to GB
- Old logs not deleted

**Diagnosis:**
```bash
# Check disk usage
du -sh ~/openclaw/memory/

# Count log files
ls ~/openclaw/memory/*.log | wc -l
```

**Solution: Manual cleanup**
```bash
# Delete logs older than 14 days
find ~/openclaw/memory -name "healthcheck-*.log" -mtime +14 -delete
find ~/openclaw/memory -name "emergency-recovery-*.log" -mtime +14 -delete
find ~/openclaw/memory -name "claude-session-*.log" -mtime +14 -delete
```

**Prevention: Add cleanup cron**
```bash
openclaw cron add \
  --name "Log Rotation (Self-Healing)" \
  --schedule '0 3 * * *' \
  --command 'find ~/openclaw/memory -name "*healthcheck*.log" -o -name "*emergency-recovery*.log" -o -name "*claude-session*.log" -mtime +14 -delete' \
  --session isolated
```

---

### Issue: Scripts fail with "Permission denied"

**Symptoms:**
- LaunchAgent logs show: `Permission denied: gateway-healthcheck.sh`

**Solution:**
```bash
chmod +x ~/openclaw/scripts/*.sh
```

---

### Issue: Environment variables not loading

**Symptoms:**
- Scripts use default values instead of custom `.env` settings

**Diagnosis:**
```bash
# Check .env exists
ls -lh ~/.openclaw/.env

# Check .env syntax
cat ~/.openclaw/.env | grep -v '^#' | grep '='
```

**Solution: Fix .env syntax**
```bash
# Edit .env
nano ~/.openclaw/.env

# Correct format:
# KEY="value"  ✅
# KEY='value'  ✅
# KEY=value    ✅
#
# KEY = "value"  ❌ (spaces around =)
# KEY="value   ❌ (missing closing quote)

# Reload LaunchAgent after fixing
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

---

## 🧪 Testing & Validation

### Force trigger each level

#### Test Level 1: Watchdog
```bash
kill -9 $(pgrep -f openclaw-gateway)
sleep 180
curl http://localhost:18789/
```

#### Test Level 2: Health Check
```bash
# Stop Gateway
openclaw gateway stop

# Wait for Health Check (5 min max)
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log

# Should see restart attempts
```

#### Test Level 3: Claude Recovery
```bash
# Inject config error (backup first!)
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak

# Break config (e.g., change port to invalid value)
# Then restart Gateway and wait ~8 min

# Watch Level 3 trigger
tail -f ~/openclaw/memory/emergency-recovery-*.log
```

#### Test Level 4: Discord Alert
```bash
# Simulate Level 3 failure
cat > ~/openclaw/memory/emergency-recovery-test-$(date +%Y-%m-%d-%H%M).log << 'EOF'
[2026-02-06 20:00:00] === Emergency Recovery Started ===
[2026-02-06 20:30:00] Gateway still unhealthy (HTTP 500)

=== MANUAL INTERVENTION REQUIRED ===
Level 1 (Watchdog) ❌
Level 2 (Health Check) ❌
Level 3 (Claude Recovery) ❌
EOF

# Run monitor
bash ~/openclaw/scripts/emergency-recovery-monitor.sh

# Check Discord for alert
```

---

## 📚 Advanced Troubleshooting

### Enable debug logging

Add to scripts (temporary):

```bash
# In gateway-healthcheck.sh
set -x  # Enable bash debug mode

# View verbose output
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log
```

### Check macOS system logs

```bash
# Filter for openclaw-related errors
log show --predicate 'process == "launchd" AND eventMessage CONTAINS "openclaw"' --last 1h

# Check LaunchAgent errors
log show --predicate 'subsystem == "com.apple.launchd"' --last 1h
```

### Verify Gateway port

```bash
# Check what's listening on 18789
lsof -i :18789

# Expected: openclaw-gateway process
```

### Check for port conflicts

```bash
# Find processes using common ports
lsof -i :18789
lsof -i :8080
lsof -i :3000

# If conflict, change Gateway port in ~/.openclaw/openclaw.json
```

---

## 🆘 Still Stuck?

### Get help from the community

1. **GitHub Issues:** [github.com/ramsbaby/openclaw-self-healing/issues](https://github.com/ramsbaby/openclaw-self-healing/issues)
2. **OpenClaw Discord:** [discord.com/invite/clawd](https://discord.com/invite/clawd)
3. **Include in your report:**
   - macOS version: `sw_vers`
   - OpenClaw version: `openclaw version`
   - Self-Healing logs: Last 50 lines of `healthcheck-*.log` and `emergency-recovery-*.log`
   - Script versions: `head -5 ~/openclaw/scripts/*.sh`

---

<p align="center">
  <strong>Most issues are config or permissions related.</strong><br>
  When in doubt, check <code>.env</code> and re-run <code>chmod +x</code>.
</p>
