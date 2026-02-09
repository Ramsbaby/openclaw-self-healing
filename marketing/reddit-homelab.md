# Reddit Post - r/homelab

**Title:** Self-healing AI agent setup — Claude Code automatically fixes crashes on my home server

**Body:**

Running an AI agent (OpenClaw) in my homelab. It's great until it's not — crashes, config errors, port conflicts.

I got tired of SSH-ing in at odd hours, so I built a self-healing system.

## How it works:

**4-tier escalation:**

1. **Watchdog (180s)** — Process alive? No → restart
2. **Health Check (300s)** — HTTP 200? No → retry 3x → escalate
3. **Claude Recovery (30min)** — Launch Claude Code in tmux → diagnose → fix root cause
4. **Discord Alert** — Human intervention needed (last resort)

## The interesting part: Level 3

Claude Code (Anthropic's CLI) acts as an emergency doctor. When it triggers:

- Reads OpenClaw logs
- Validates config (JSON syntax, port bindings)
- Checks dependencies
- Attempts fixes (config edits, restarts)
- Generates a recovery report

**It's autonomous troubleshooting.** The agent heals itself.

## Real failures it caught:

- Watchdog hung after SIGUSR1 → kickstarted by cron guardian
- Config typo → Claude fixed JSON syntax error
- Port 18789 conflict → Claude identified, documented (human fix)

**Success rate:** 2/3 autonomous recoveries. The 3rd (port conflict) required manual resolution, but it was diagnosed correctly.

## Stack:

- 4 bash scripts (~400 lines total)
- 1 LaunchAgent (macOS, but systemd equivalents exist)
- 1 cron job
- Claude Code CLI (free tier works)
- tmux (for PTY session)

## Deployment:

```bash
curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash
```

That's it. 30 seconds to a self-healing homelab.

## Results:

- **Uptime:** 99.5% (post-deployment)
- **Manual interventions:** 1 in 7 days
- **Longest recovery:** 25 minutes (Level 3)
- **Cost:** $0/month (Claude free tier)

## GitHub:

https://github.com/Ramsbaby/openclaw-self-healing

Current version: v2.0.1 (includes persistent learning — Claude remembers past incidents)

## Why post this here?

Homelabs are supposed to be reliable. But they're also supposed to be *fun*. Spending weekends SSH-ing into crashed services isn't fun.

If your infra can heal itself, you can focus on building, not firefighting.

Anyone else automating recovery in their homelab? Curious what approaches you're using.

---

**TL;DR:** AI agent crashes, Claude Code diagnoses + fixes it autonomously. 99.5% uptime, minimal human intervention. GitHub + one-click install available.
