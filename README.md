<div align="center">

# 🦞 OpenClaw Self-Healing System

### *Autonomous AI-Powered Recovery for Production Services*

**Stop getting paged at 3 AM. Let AI fix your crashes automatically.**

[![Version](https://img.shields.io/badge/version-3.2.0-blue.svg)](https://github.com/Ramsbaby/openclaw-self-healing/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](#-quick-start)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/ramsbaby/openclaw-self-healing?style=social)](https://github.com/ramsbaby/openclaw-self-healing/stargazers)

[🚀 Quick Start](#-quick-start) · [🎬 Demo](#-demo) · [🏗️ Architecture](#️-architecture) · [📖 Docs](docs/)

</div>

---

## 🎬 Demo

<div align="center">

![Self-Healing Demo](https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/assets/demo.gif)

*4-tier recovery in action: KeepAlive → Watchdog → AI Doctor → Alert*

</div>

---

## 🔥 Why This Exists

Your OpenClaw Gateway crashes at midnight. A basic watchdog restarts it — but what if the config is corrupted? The API rate limit hit? A dependency broken?

**Simple restart = crash loop.** You get paged. Your weekend is ruined.

**This system doesn't just restart — it understands and fixes root causes.**

---

## 🚀 Quick Start

### Prerequisites

- **macOS 12+** or **Linux** (Ubuntu 20.04+ / systemd)
- **[OpenClaw Gateway](https://github.com/openclaw/openclaw)** installed and running
- **[Claude CLI](https://docs.anthropic.com/claude/docs/claude-code)** with Anthropic API key
- `tmux`, `jq` (`brew install tmux jq` or `apt install tmux jq`)

### Install (5 minutes)

```bash
curl -fsSL https://raw.githubusercontent.com/ramsbaby/openclaw-self-healing/main/install.sh | bash
```

The installer walks you through everything:

```
╔═══════════════════════════════════════════════╗
║  🦞 OpenClaw Self-Healing System Installer    ║
╚═══════════════════════════════════════════════╝

[1/6] Checking prerequisites...          ✅
[2/6] Creating directories...            ✅
[3/6] Installing scripts...              ✅
[4/6] Configuring environment..
      Discord webhook URL (optional): https://discord.com/api/webhooks/...
      Gateway port [18789]: 
      Gateway token (auto-detected): ✅
[5/6] Installing Watchdog LaunchAgent... ✅
[6/6] Verifying installation...
      Health check: HTTP 200 ✅
      Chain: Watchdog → HealthCheck → Emergency Recovery ✅

🎉 Self-Healing System Active!
```

### Verify It Works

```bash
# Kill your Gateway to test auto-recovery
kill -9 $(pgrep -f openclaw-gateway)

# Wait ~30 seconds, then check
curl http://localhost:18789/
# Expected: HTTP 200 ✅
```

---

## 🎬 How It Works

### 5-Tier Autonomous Recovery

```mermaid
graph TD
    A[🚀 LaunchAgent Starts Gateway] --> B[Level 0: Preflight]
    B -->|"Config valid"| C[exec gateway — launchd tracks PID]
    B -->|"Config invalid"| D[AI Recovery Session + backoff → retry]
    C --> E{Stable?}
    E -->|Repeated crashes| F[Level 1: KeepAlive]
    F -->|"Instant restart (0-30s)"| G{Stable?}
    G -->|Yes| Z[✅ Online]
    G -->|Repeated crashes| H[Level 2: Watchdog]
    H -->|"HTTP check every 3min"| I{Stable?}
    I -->|Yes| Z
    I -->|"30min continuous failure"| J[Level 3: Claude AI]
    J -->|"Autonomous diagnosis & fix"| K{Fixed?}
    K -->|Yes| Z
    K -->|No| L[Level 4: Human Alert]
    L -->|"Discord / Telegram"| M[👤 Manual Fix]

    style A fill:#74c0fc
    style B fill:#74c0fc
    style Z fill:#51cf66
    style J fill:#4dabf7
```

### Each Level Explained

| Level | What | When | How |
|-------|------|------|-----|
| **0** | Preflight Validation | Every cold start | Validate binary, .env keys, JSON configs before exec |
| **1** | LaunchAgent KeepAlive | Any crash | Instant restart (0–30s) |
| **2** | Watchdog v4.1 + HealthCheck | Repeated crashes | PID + HTTP + memory monitoring, exponential backoff |
| **3** | Claude AI Emergency Recovery | 30min continuous failure | PTY session → log analysis → auto-fix |
| **4** | Human Alert | All automation fails | Discord/Telegram with full context |

**Level 0 (new in v3.2):** Catches config corruption, missing .env keys, and broken JSON *before* the gateway even starts — preventing crash loops from bad config entirely.

---

## 📊 Real Production Numbers

Based on an audit of 14 real incidents (Feb 2026):

| Scenario | Result |
|----------|--------|
| 17 consecutive crashes | ✅ Full recovery via Level 1 |
| Config corruption | ✅ Auto-fixed in ~3 min |
| All services killed (nuclear) | ✅ Recovered in ~3 min |
| 38+ crash loop | ⛔ Stopped by design (prevents infinite loops) |

**9 of 14 incidents resolved fully autonomously.** The remaining 5 escalated correctly to Level 4 — the system worked as designed.

---

## 🏗️ Architecture

```
Level 0: Preflight 🔍 (every cold start)
│  Validates binary, .env keys, JSON configs before exec
│  On failure: AI recovery session (tmux) + exponential backoff
│  scripts/gateway-preflight.sh
│
▼  passes
Level 1: KeepAlive ⚡ (0-30s)
│  Instant restart on any crash
│  Built into ai.openclaw.gateway.plist
│
▼  repeated failures
Level 2: Watchdog v4.1 🔍 (3-5 min)
│  HTTP + PID + memory monitoring every 3 min
│  Exponential backoff: 10s → 30s → 90s → 180s → 600s
│  Crash counter auto-decay after 6 hours
│
▼  30 minutes of continuous failure
Level 3: AI Emergency Recovery 🧠 (5-30 min)
│  Auto-triggered — no manual intervention
│  Claude Code PTY: reads logs → diagnoses → fixes
│  Documents learnings for future incidents
│
▼  all automation fails
Level 4: Human Alert 🚨
   Discord/Telegram notification with full context
   Log paths + recovery report attached
```

### Scripts Reference

| Script | Level | Purpose |
|--------|-------|---------|
| `scripts/gateway-preflight.sh` | 0 | Proactive config validation before service start |
| `scripts/gateway-watchdog.sh` | 2 | Reactive recovery after crash detection |
| `scripts/gateway-healthcheck.sh` | 2 | HTTP health polling + Level 3 escalation |
| `scripts/emergency-recovery-v2.sh` | 3 | Claude AI autonomous diagnosis and repair |
| `scripts/emergency-recovery-monitor.sh` | 3 | Monitor active recovery sessions |

---

## ✅ What v3.2 Added

| Before v3.2 | After v3.2 |
|-------------|------------|
| Config corruption caused crash loops at start | Preflight catches it before exec |
| `ANTHROPIC_API_KEY` silently missing in tmux sessions spawned from launchd | Key forwarded via `tmux -e` flag |
| No proactive validation layer | Level 0: gateway-preflight.sh |

### Previous: What v3.1 Fixed

| Before v3.1 | After v3.1 |
|-------------|-----------| 
| Manual LaunchAgent/systemd setup | `install.sh` does everything |
| `.env` had to be created by hand | Interactive wizard generates it |
| Level 2 → Level 3 was disconnected | Auto-triggers after 30 min |
| macOS only | macOS + Linux (systemd) |
| Install often failed mid-way | Verified end-to-end |

---

## 🗺️ Roadmap

**✅ Done:** 4-tier architecture · Claude AI integration · `install.sh` automation · Linux systemd · Level 2→3 auto-escalation · Discord/Telegram alerts · Preflight validation (v3.2)

**🚧 Next:** Docker image · Alternative LLMs (GPT-4, Gemini) · Prometheus metrics · Grafana dashboard

**🔮 Future:** Multi-node clusters · Kubernetes Operator

[🗳️ Vote on features →](https://github.com/ramsbaby/openclaw-self-healing/discussions)

---

## 📚 Docs

| | |
|---|---|
| [📖 Quick Start](docs/QUICKSTART.md) | Installation guide |
| [🏗️ Architecture](docs/architecture.md) | System design |
| [🔧 Configuration](docs/configuration.md) | Environment variables |
| [🐛 Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues |
| [📜 Changelog](CHANGELOG.md) | Version history |

---

## 🔒 Security

No secrets in code. `.env` for all webhooks. Lock files prevent races. All recoveries logged.

Level 3 Claude access: OpenClaw config, gateway restart, log files — intentional for autonomous recovery.

---

## 🧠 Companion: MemoryBox

Self-Healing recovers from crashes. **[MemoryBox](https://github.com/Ramsbaby/openclaw-memorybox)** prevents the memory bloat that causes them. Both MIT licensed, both battle-tested on the same production instance.

---

## 🤝 Contributing

Bug reports, feature requests, docs improvements welcome. [📋 Contribution Guide →](CONTRIBUTING.md)

**Community:** [Discussions](https://github.com/ramsbaby/openclaw-self-healing/discussions) · [Issues](https://github.com/ramsbaby/openclaw-self-healing/issues) · [Discord](https://discord.com/invite/clawd)

---

<div align="center">

**MIT License** · Made with 🦞 by [@ramsbaby](https://github.com/ramsbaby)

*"The best system is one that fixes itself before you notice it's broken."*

</div>
