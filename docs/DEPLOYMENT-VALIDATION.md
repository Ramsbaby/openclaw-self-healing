# Deployment Validation Checklist

After installing openclaw-self-healing, run through this checklist to verify each recovery level works.

## Quick Automated Validation

```bash
bash scripts/validate-deployment.sh
```

## Manual Validation Steps

### Level 0: Preflight
- [ ] Corrupt a non-critical config value → preflight should reject and log error
- [ ] Remove a required `.env` key → preflight should fail with clear message
- [ ] Verify `set -u` safety: unset a shell variable and confirm no silent crash

### Level 1: KeepAlive
- [ ] `kill -9 $(pgrep -f openclaw-gateway)` → service restarts within 30s
- [ ] Verify via `launchctl list | grep openclaw` — PID should change

### Level 2: Watchdog + HealthCheck
- [ ] Stop gateway, wait 3 min → watchdog detects and restarts
- [ ] Verify exponential backoff: check watchdog log for increasing delays
- [ ] Confirm crash counter decays after 6 hours of stability

### Level 3: AI Emergency Recovery
- [ ] Verify Claude/LLM binary exists at configured path
- [ ] Test tmux session creation: `tmux new-session -d -s test-heal -e "PATH=/opt/homebrew/bin:/usr/bin:/bin" echo ok`
- [ ] Confirm API key is available in tmux env (launchd doesn't inherit user env)

### Level 4: Human Alert
- [ ] Send test notification: `source scripts/lib/notify.sh && send_notification "test" "deployment validation"`
- [ ] Verify Discord/Slack/Telegram message arrives
- [ ] Check ntfy.sh topic subscription on mobile device

## Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `env: node: No such file or directory` | LaunchAgent PATH doesn't include node | Use absolute path in plist or export PATH in preflight |
| `NODE_PATH: unbound variable` | `set -u` + missing NODE_PATH default | Add `NODE_PATH="${NODE_PATH:-}"` before use |
| Alerts logged but not received | ntfy topic not subscribed on phone | Open `ntfy.sh/YOUR_TOPIC` in mobile app |
| First L3 attempt fails silently | tmux session env missing API keys | Pass keys via `tmux -e "KEY=value"` |
| npm install fails in cron/launchd | PATH doesn't include node binary dir | `export PATH="$(dirname "$NODE_BIN"):$PATH"` before npm |
