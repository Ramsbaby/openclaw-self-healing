---
title: "I Built an AI Doctor for My AI Agent — Here's How It Works"
published: false
description: "A 4-tier self-healing system that uses Claude Code to autonomously diagnose and fix crashes"
tags: ai, devops, automation, opensource
cover_image: https://github.com/Ramsbaby/openclaw-self-healing/raw/main/assets/demo.gif
---

# I Built an AI Doctor for My AI Agent

**TL;DR:** My AI agent kept crashing at 3am. So I built another AI to fix it.

## The Problem

I run [OpenClaw](https://github.com/openclaw/openclaw), an AI agent framework, on a Mac Mini. It's great until it crashes at 3am and I wake up to a dead assistant.

Traditional watchdogs just restart the process. They don't understand *why* it crashed.

## The Solution: 4-Tier Self-Healing

```
Level 1: Watchdog (180s)     → Process dead? Restart.
Level 2: Health Check (300s) → HTTP failing? Retry 3x.
Level 3: Claude Doctor (30m) → AI diagnosis + autonomous fix 🧠
Level 4: Discord Alert       → Human escalation
```

### The Interesting Part: Level 3

When Levels 1-2 fail, the system launches **Claude Code** (Anthropic's CLI) in a tmux PTY session:

```bash
tmux new-session -d -s emergency-recovery
tmux send-keys "claude --dangerously-skip-permissions" Enter
tmux send-keys "Gateway is down. Diagnose and fix." Enter
```

Claude then:
1. Runs `openclaw status`
2. Reads system logs
3. Identifies root cause (stale PID, port conflict, config error...)
4. Executes fixes
5. Verifies recovery

**All logged. All auditable.**

## Security Model

- Isolated tmux session (no main session access)
- Read-only config access
- 30-minute hard timeout
- Cleanup trap prevents orphan processes
- Level 4 watchdog monitors Level 3

## The Philosophy

> "If we trust AI to write code, why not trust it to fix infrastructure?"

The AI already knows how to diagnose problems — it does it every day when developers ask for help. We just gave it permission to act on its diagnosis.

## Results

- Recovery time: 25 seconds (vs 8+ hours waiting for human)
- False positives: 0 (so far)
- My sleep quality: Improved 🛌

## Try It

MIT licensed. Bash scripts only. Works on macOS (Linux guide included).

{% github Ramsbaby/openclaw-self-healing %}

---

*What do you think? Would you trust an AI doctor for your infrastructure?*
