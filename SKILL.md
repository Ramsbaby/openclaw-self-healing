---
name: openclaw-self-healing
version: 3.4.0
description: Five-level autonomous self-healing system for OpenClaw Gateway with preflight config validation, persistent learning, reasoning logs, and multi-channel alerts. Features Claude Code as the Level 3 emergency doctor for AI-powered diagnosis and repair.
metadata:
  {
    "openclaw":
      {
        "requires": { "bins": ["tmux", "claude", "jq"] },
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
            {
              "id": "jq",
              "kind": "brew",
              "package": "jq",
              "bins": ["jq"],
              "label": "Install jq (brew) - required by install-linux.sh",
            },
          ],
      },
  }
---

# OpenClaw Self-Healing System

> **"The system that heals itself — or calls for help when it can't."**

A five-level autonomous self-healing system for OpenClaw Gateway.

## Architecture

```
Level 0: Preflight            → Validate binary/.env/JSON, then exec the gateway
Level 1: KeepAlive            → Instant restart (owned by the gateway service unit)
Level 2: Watchdog (180s)      → PID + HTTP + memory, exponential backoff
         Health Check (300s)  → HTTP 200 + 3 retries → Level 3 escalation
Level 3: Claude Recovery      → 30min AI-powered diagnosis in a tmux PTY session
Level 4: Multi-channel Alert  → Human escalation
```

## What's Special

- Claude Code CLI as the Level 3 emergency doctor, with a mandatory "read real state
  before diagnosing" prompt block to curb hallucinated fixes
- **Preflight validation (Level 0)** — catches config corruption before the gateway starts
- **Persistent learning** — recovery documentation (symptom → cause → solution → prevention)
- **Reasoning logs** — the AI's decision-making process is written to disk
- **Multi-channel alerts** — Discord, Slack and Telegram via `scripts/lib/notify.sh`
- **Prometheus metrics** — eight gauges for Grafana dashboards and alert rules
- Production-tested: 9 of 14 real incidents resolved autonomously (64%)
- macOS LaunchAgent and Linux systemd integration

## Quick Setup

### Recommended: one-line installer

```bash
curl -fsSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash
```

Preview first with `bash -s -- --dry-run`. The installer handles dependencies check,
directories, script download, `.env` generation and LaunchAgent/systemd registration.

### Manual setup

#### 1. Install dependencies

```bash
brew install tmux
npm install -g @anthropic-ai/claude-code
```

#### 2. Configure environment

```bash
cp .env.example ~/.openclaw/.env
chmod 600 ~/.openclaw/.env
nano ~/.openclaw/.env    # add your webhook and gateway token
```

#### 3. Install scripts

Scripts must live where the LaunchAgents and escalation paths expect them:

```bash
DEST=~/.openclaw/skills/openclaw-self-healing/scripts
mkdir -p "$DEST/lib"
cp scripts/*.sh "$DEST/"
cp scripts/lib/*.sh "$DEST/lib/"
chmod 700 "$DEST"/*.sh "$DEST"/lib/*.sh

cp launchagent/com.openclaw.healthcheck.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

#### 4. Verify

```bash
launchctl list | grep openclaw.healthcheck
bash scripts/validate-deployment.sh
tail -f ~/.openclaw/logs/watchdog.log
```

## Scripts

| Script | Level | Description |
|--------|-------|-------------|
| `gateway-preflight.sh` | 0 | Config validation before start; `exec`s the gateway on success |
| `gateway-watchdog.sh` | 2 | PID + HTTP + memory monitoring, backoff, `doctor --fix`, L3 escalation |
| `gateway-healthcheck.sh` | 2 | HTTP 200 check + 3 retries + escalation |
| `emergency-recovery-v2.sh` | 3 | Claude PTY session with learning + reasoning logs (the one L0/L2 call) |
| `emergency-recovery.sh` | 3 | Earlier v1 recovery script; not installed by the installers |
| `emergency-recovery-monitor.sh` | 4 | Alerts when a recovery session fails |
| `lib/notify.sh` | 4 | Discord / Slack / Telegram dispatcher |
| `lib/llm-gateway.sh` | — | LLM provider router; not yet called by any script |
| `validate-deployment.sh` | ops | Post-install verification of all five levels |
| `incident-digest.sh` | ops | Weekly incident report |
| `prometheus-exporter.py` | ops | Metrics HTTP server (requires `python3`) |

## Configuration

All settings via environment variables in `~/.openclaw/.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DISCORD_WEBHOOK_URL` | (none) | Discord webhook for alerts |
| `SLACK_WEBHOOK_URL` | (none) | Slack webhook, `lib/notify.sh` only |
| `NOTIFICATION_CHANNEL` | auto-detect | Force `discord` / `slack` / `telegram` |
| `OPENCLAW_GATEWAY_URL` | `http://localhost:18789/` | Gateway health check URL |
| `OPENCLAW_GATEWAY_TOKEN` | (none) | Required by Level 0 preflight |
| `ANTHROPIC_API_KEY` | (none) | Required by Levels 0 and 3 |
| `HEALTH_CHECK_MAX_RETRIES` | `3` | Restart attempts before escalation |
| `OPENCLAW_WATCHDOG_ESCALATE_TO_L3_AFTER` | `1800` | Continuous-failure seconds before Level 3 |
| `EMERGENCY_RECOVERY_TIMEOUT` | `1800` | Claude recovery timeout (30 min) |

See `.env.example` for the full annotated list.

## Testing

### Test Level 2 (Health Check)

```bash
# Run manually
bash ~/.openclaw/skills/openclaw-self-healing/scripts/gateway-healthcheck.sh

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
