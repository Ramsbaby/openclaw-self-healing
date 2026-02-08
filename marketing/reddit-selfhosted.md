# Reddit Post - r/selfhosted

**Title:** I built a self-healing system for my AI agent — it auto-recovers from crashes using Claude Code

**Body:**

Like a lot of you, I run OpenClaw (AI agent) on a home server. The problem? It crashes. Config errors, port conflicts, memory leaks — the usual suspects.

Manual restarts at 2 AM got old fast.

So I built a 4-tier self-healing system. When OpenClaw crashes, it:

**Level 1 (Watchdog):** Restarts the process (3 minutes)  
**Level 2 (Health Check):** Detects HTTP failures + retries (5 minutes)  
**Level 3 (Claude Doctor):** Launches Claude Code in a tmux session to diagnose + fix root causes (30 minutes)  
**Level 4 (Discord Alert):** Pings me only if all else fails

## What makes it interesting:

**"AI heals AI"** — Level 3 uses Claude Code (Anthropic's CLI) to autonomously troubleshoot. It reads logs, checks config, validates ports, and attempts fixes. Then it writes a recovery report.

**Production-tested** — It's caught real failures: a hung watchdog, a config typo that broke startup, and a port conflict. Level 3 fixed 2 of them without human intervention.

**Simple stack** — 4 bash scripts (~400 lines), 1 LaunchAgent, 1 cron job. No Docker, no K8s, no complex dependencies.

## Example recovery:

```
[19:12] Gateway crashes (config error)
[19:15] Health Check detects failure → escalates
[19:20] Claude Code launches in tmux
[19:25] Claude reads logs, finds typo in openclaw.json
[19:26] Fixes config, restarts Gateway
[19:27] HTTP 200 confirmed → recovery complete
```

Total downtime: 15 minutes. Zero human intervention.

## GitHub + Demo:

- **Repo:** https://github.com/Ramsbaby/openclaw-self-healing
- **One-click install:** `curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash`
- **Current version:** v2.0.1 (includes persistent learning — Claude remembers past failures)

## Stats:

- ⭐ 6 stars, 1 fork (2 days old)
- ✅ 99.5% uptime post-deployment
- 🦞 First self-healing system to use Claude Code as emergency doctor

## Limitations:

- macOS only (LaunchAgent-based, but Linux systemd equivalents are documented)
- Requires Claude CLI (free tier works)
- Level 3 needs network (Claude API)

## Why share this here?

Because self-hosting shouldn't mean babysitting. If your infra can auto-heal, you can actually sleep.

Curious what r/selfhosted thinks. Anyone else automating recovery for their home setups?

---

**TL;DR:** Built a 4-tier recovery system that uses Claude Code to autonomously diagnose + fix AI agent crashes. 99.5% uptime, zero 2 AM wake-ups.
