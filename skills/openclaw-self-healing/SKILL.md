---
name: openclaw-self-healing
version: 1.3.4
description: 4-tier autonomous self-healing system for OpenClaw Gateway. Features Claude Code as Level 3 emergency doctor for AI-powered diagnosis and repair. Includes Watchdog, Health Check, Claude Recovery, and Discord Alert levels.
metadata:
  {
    "openclaw":
      {
        "requires": { "bins": ["tmux", "claude"] },
        "install":
          [
            {
              "id": "tmux",
              "kind": "brew",
              "package": "tmux",
              "bins": ["tmux"],
              "label": "Install tmux (brew)",
            },
            {
              "id": "claude",
              "kind": "node",
              "package": "@anthropic-ai/claude-code",
              "bins": ["claude"],
              "label": "Install Claude Code CLI (npm)",
            },
          ],
      },
  }
---

# OpenClaw Self-Healing System

> **"The system that heals itself — or calls for help when it can't."**

A 4-tier autonomous self-healing system for OpenClaw Gateway.

## Architecture

```
Level 1: Watchdog (180s)     → Process monitoring (OpenClaw built-in)
Level 2: Health Check (300s) → HTTP 200 + 3 retries
Level 3: Claude Recovery     → 30min AI-powered diagnosis 🧠
Level 4: Discord Alert       → Human escalation
```

## What's Special

- **World's first** Claude Code as Level 3 emergency doctor
- Claude runs in tmux PTY, reads logs, diagnoses, and fixes autonomously
- Production-tested (verified recovery Feb 5, 2026)
- macOS LaunchAgent integration

## Quick Setup

### 1. Install Dependencies

```bash
brew install tmux
npm install -g @anthropic-ai/claude-code
```

### 2. Configure Environment

```bash
# Copy template to OpenClaw config directory
cp .env.example ~/.openclaw/.env

# Edit and add your Discord webhook (optional)
nano ~/.openclaw/.env
```

### 3. Install Scripts

```bash
# Copy scripts
cp scripts/*.sh ~/openclaw/scripts/
chmod +x ~/openclaw/scripts/*.sh

# Install LaunchAgent
cp launchagent/com.openclaw.healthcheck.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

### 4. Verify

```bash
# Check Health Check is running
launchctl list | grep openclaw.healthcheck

# View logs
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log
```

## Scripts

| Script | Level | Description |
|--------|-------|-------------|
| `gateway-healthcheck.sh` | 2 | HTTP 200 check + 3 retries + escalation |
| `emergency-recovery.sh` | 3 | Claude Code PTY session for AI diagnosis |
| `emergency-recovery-monitor.sh` | 4 | Discord notification on failure |

## Configuration

All settings via environment variables in `~/.openclaw/.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DISCORD_WEBHOOK_URL` | (none) | Discord webhook for alerts |
| `OPENCLAW_GATEWAY_URL` | `http://localhost:18789/` | Gateway health check URL |
| `HEALTH_CHECK_MAX_RETRIES` | `3` | Restart attempts before escalation |
| `EMERGENCY_RECOVERY_TIMEOUT` | `1800` | Claude recovery timeout (30 min) |

## Testing

### Test Level 2 (Health Check)

```bash
# Run manually
bash ~/openclaw/scripts/gateway-healthcheck.sh

# Expected output:
# ✅ Gateway healthy
```

### Test Level 3 (Claude Recovery)

```bash
# Inject a config error (backup first!)
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak

# Wait for Health Check to detect and escalate (~8 min)
tail -f ~/openclaw/memory/emergency-recovery-*.log
```

## Links

- **GitHub:** https://github.com/Ramsbaby/openclaw-self-healing
- **Docs:** https://github.com/Ramsbaby/openclaw-self-healing/tree/main/docs

## License

MIT License - do whatever you want with it.

Built by @ramsbaby + Jarvis 🦞
