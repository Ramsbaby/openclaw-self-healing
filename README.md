<div align="center">

# 🦞 OpenClaw Self-Healing System v3.0

**Automatic 4-tier crash recovery for OpenClaw Gateway — no pager, no panic.**

[![GitHub Stars](https://img.shields.io/github/stars/ramsbaby/openclaw-self-healing?style=social)](https://github.com/ramsbaby/openclaw-self-healing/stargazers)
[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/Ramsbaby/openclaw-self-healing/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](docs/LINUX_SETUP.md)

</div>

---

## The Problem

Your OpenClaw Gateway crashes at 3 AM. A simple restart doesn't help — the config is corrupted, the DB connection is stale, or the API rate limit is exceeded. You're paged. Your sleep is ruined.

Traditional watchdogs restart. They don't **diagnose**.

---

## The Solution

This is not magic. It's **four escalating layers of automation**, with AI diagnosis as a last resort before calling a human.

- 🔁 **Instant restart** via LaunchAgent KeepAlive (0–30 s)
- 🔍 **Root-cause fix** via Watchdog + `doctor --fix` (3–5 min)
- 🧠 **AI diagnosis** via Claude Code autonomous session (5–10 min)
- 🚨 **Human alert** via Discord with full context (last resort)

---

## Quick Demo

```
$ openclaw gateway restart   # simulate a crash

[00:00] 🔁 Level 0: KeepAlive triggered — restarting...
[00:05] ⚠️  Crash detected again (count: 2)
[00:05] 🔍 Level 1: Watchdog running doctor --fix...
[00:47] ✅ doctor --fix: config restored from backup
[00:48] 🟢 Gateway online — recovery time: 48 seconds

# Worst-case scenario (config + DB broken):
[00:00] 🔁 Level 0–2: auto-restart & doctor failed (2x)
[03:10] 🧠 Level 3: Spawning Claude AI emergency session...
[07:22] 🔍 Claude: Found stale lock file + expired token
[07:44] 🛠️  Claude: Applied fix, restarting gateway...
[08:01] 🟢 Gateway online — recovery time: 8 min 1 sec
```

---

## Installation

**Prerequisites:** macOS 12+ or Linux, OpenClaw Gateway, Claude CLI, `tmux`, `jq`

```bash
curl -fsSL https://raw.githubusercontent.com/ramsbaby/openclaw-self-healing/main/install.sh | bash
```

The installer verifies prerequisites, installs scripts and LaunchAgents, configures your environment, and runs an initial health check.

**Full guide:** [docs/QUICKSTART.md](docs/QUICKSTART.md) · **Linux:** [docs/LINUX_SETUP.md](docs/LINUX_SETUP.md)

### Verify it works

```bash
# Force a crash and watch recovery
kill -9 $(pgrep -f openclaw-gateway)
sleep 180
curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/
# → 200
```

---

## How It Works

| Tier | Trigger | Action | Typical Recovery |
|------|---------|--------|-----------------|
| **0 — KeepAlive** | Any crash | LaunchAgent instant restart + backoff | 0–30 s |
| **1–2 — Watchdog** | Repeated crash | PID/HTTP/memory check + `doctor --fix` (×2) | 3–5 min |
| **3 — AI Doctor** | `doctor --fix` fails twice | Claude Code PTY: reads logs, diagnoses, applies fix | 5–10 min |
| **4 — Human Alert** | All automation fails | Discord notification with full context + log paths | You decide |

**Crash loop guard:** Watchdog stops escalating after 5 consecutive failures — no infinite restart storms.

Architecture deep-dive: [docs/architecture.md](docs/architecture.md)

---

## NEW in v3.0: Self-Optimization

> "Now it optimizes its own configuration, too."

The previous **Self-Evolving Agent** concept is fully integrated as a weekly background task:

1. **Analyze** — Reads `AGENTS.md`, recent logs, and recovery reports once a week
2. **Propose** — Generates a diff with suggested threshold / config improvements
3. **Review** — Posts the proposal to Discord for your approval
4. **Apply** — Makes changes **only after you explicitly confirm** (never automatic)

This means the system can suggest "your memory threshold is too low — 70% of your Level 2 recoveries are false positives" and show you the exact config change. You decide.

**No silent self-modification. Ever.**

```bash
# Manual trigger (or runs automatically every Sunday 02:00)
bash scripts/self-optimize.sh --dry-run   # preview
bash scripts/self-optimize.sh             # submit proposal for approval
```

---

## Configuration

Copy `.env.example` → `.env` and set:

```bash
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...   # required for alerts
RECOVERY_TIMEOUT_SECONDS=600     # Level 3 AI timeout (default: 600)
MAX_CRASH_THRESHOLD=5            # stop escalating after N crashes (default: 5)
HEALTH_CHECK_INTERVAL=30         # watchdog poll interval in seconds (default: 30)
MEMORY_WARN_PERCENT=80           # trigger doctor above this RSS% (default: 80)
```

Full reference: [docs/configuration.md](docs/configuration.md)

---

## vs. Alternatives

| | This project | Simple watchdog | Kubernetes liveness probe |
|---|---|---|---|
| Instant restart | ✅ | ✅ | ✅ |
| Root-cause diagnosis | ✅ AI-powered | ❌ | ❌ |
| Self-optimizing config | ✅ v3.0 | ❌ | ❌ |
| macOS LaunchAgent support | ✅ | ❌ | ❌ |
| Zero-dependency core | ✅ (bash + jq) | ✅ | ❌ |
| Crash loop guard | ✅ | ❌ | ✅ |

---

## Community & Contributing

- **Discussions:** [Ask questions, share ideas](https://github.com/ramsbaby/openclaw-self-healing/discussions)
- **Bugs:** [Report an issue](https://github.com/ramsbaby/openclaw-self-healing/issues/new?template=bug_report.yml)
- **Features:** [Request or vote](https://github.com/ramsbaby/openclaw-self-healing/issues/new?template=feature_request.yml)
- **Discord:** [OpenClaw Community](https://discord.com/invite/clawd)

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines and good-first-issues.

### Companion project

**[MemoryBox](https://github.com/Ramsbaby/openclaw-memorybox)** — keeps `MEMORY.md` lean to prevent the context-overflow crashes this system recovers from. Prevention + recovery, two tools, same philosophy.

---

## License

MIT — see [LICENSE](LICENSE). No warranty, no guarantees.

---

<div align="center">

**Made with 🦞 by [@ramsbaby](https://github.com/ramsbaby)**

*"The best system is one that fixes itself before you notice it's broken."*

[⬆ Back to top](#-openclaw-self-healing-system-v30)

</div>
