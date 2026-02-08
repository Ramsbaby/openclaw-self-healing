---
title: "I Built a Self-Healing AI System Where Claude Code Acts as Emergency Doctor"
published: false
description: "4-tier autonomous recovery for OpenClaw Gateway — featuring the world's first AI-powered diagnosis and repair system"
tags: ai, devops, automation, opensource
cover_image: https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/docs/images/architecture.png
canonical_url: https://github.com/Ramsbaby/openclaw-self-healing
---

## TL;DR

- **Problem**: AI agents crash at night, no one's awake to fix them
- **Solution**: 4-tier self-healing (Watchdog → Health Check → Claude Doctor → Alert)
- **Result**: Recovery time 30min → 5min, zero manual intervention for 90% of issues
- **Unique**: Claude Code as autonomous emergency doctor (world's first!)

---

## The Wake-Up Call

*"Jarvis, why aren't you responding?"*

2 AM. My AI assistant was dead. Again.

The process was alive, but HTTP responses were timing out. Memory looked fine, but API calls were failing. Traditional process monitoring couldn't catch these "zombie" states.

**The irony**: An AI that runs 24/7 needs someone to watch it 24/7. But I need sleep.

So I built a system where **AI heals AI**.

---

## Architecture: 4 Levels of Defense

```
┌─────────────────────────────────────────────────────────┐
│ Level 1: Watchdog (60s interval)                        │
│ └─ Process dead? → Restart                              │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ Level 2: Health Check (300s interval)                   │
│ └─ HTTP 200 failing? → 3 retries → Level 3              │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ Level 3: Claude Emergency Recovery (30m timeout) 🧠     │
│ ├─ Launch Claude Code in tmux PTY                       │
│ ├─ Autonomous diagnosis (logs, config, ports)          │
│ ├─ Autonomous repair (fix & restart)                   │
│ └─ Generate recovery report                             │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ Level 4: Human Alert (Discord notification) 🚨          │
│ └─ Only when AI doctor fails                            │
└─────────────────────────────────────────────────────────┘
```

---

## The Secret Sauce: Claude as Doctor

Level 3 is where the magic happens. When Levels 1-2 fail, we spawn Claude Code in a tmux PTY session with this prompt:

```
You are an OpenClaw Gateway emergency doctor.
The gateway has been unresponsive for 5+ minutes.

Diagnose and fix the issue:
1. Check `openclaw status`
2. Analyze recent logs
3. Validate configuration
4. Check for port conflicts
5. Attempt repairs
6. Verify HTTP 200 response

You have 30 minutes. Save humanity.
```

Claude then autonomously:
- Reads logs and identifies patterns
- Checks configuration for errors
- Restarts services with fixes
- Validates the repair worked

**It's like having a senior DevOps engineer on call 24/7.**

---

## Real-World Results

| Metric | Before | After |
|--------|--------|-------|
| Avg recovery time | 30 min | 5 min |
| Night incidents resolved | 0% | 90% |
| Manual interventions/week | 5 | 0.5 |

The system has been running in production for 2 weeks. Level 3 (Claude Doctor) has been triggered twice and successfully resolved both issues without human intervention.

---

## Try It Yourself

```bash
# One-click install
curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash
```

**GitHub**: https://github.com/Ramsbaby/openclaw-self-healing
**ClawHub**: `clawhub install openclaw-self-healing`

---

## What's Next?

- [ ] Linux support (currently macOS only)
- [ ] Multi-node healing
- [ ] Cost optimization (Claude API isn't free!)

---

*Have you built self-healing systems for AI agents? I'd love to hear your approach in the comments!*

🦞 Built with love for the OpenClaw community
