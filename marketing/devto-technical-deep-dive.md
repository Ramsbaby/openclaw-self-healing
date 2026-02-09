# How I Built a Self-Healing AI System (with Claude Code as Emergency Doctor)

**Tags:** #ai #opensource #automation #devops

---

## The Problem

I run OpenClaw (an AI assistant) on a Mac Mini in my home office. It's great... until it crashes.

**Common failure modes:**
- Config typos (invalid JSON)
- Port conflicts (18789 already bound)
- Memory leaks (process bloat)
- Dependency issues (missing npm packages)
- Network failures (API timeouts)

Manual recovery flow:
1. Notice it's down (Discord bot silent, or I try to use it)
2. SSH into the machine
3. Check logs (`tail ~/.openclaw/logs/*.log`)
4. Diagnose the issue
5. Fix it (config edit, `kill -9`, restart)
6. Monitor for 5 minutes to confirm recovery

**Time cost:** 10-30 minutes per incident. **Frequency:** 2-3x per week.

That's 60-90 minutes per week babysitting a system that's supposed to help me.

## The Solution: 4-Tier Self-Healing

I built an autonomous recovery system with escalating intervention levels. Think of it like a hospital triage system.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│ Level 1: Watchdog (180s interval) 🔍                   │
│ ├─ PID check + HTTP health check                       │
│ ├─ Exponential backoff (10s → 600s)                    │
│ └─ SIGUSR1 graceful restart or launchctl kickstart     │
└─────────────────────────────────────────────────────────┘
 ↓ (if Watchdog fails)
┌─────────────────────────────────────────────────────────┐
│ Level 2: Health Check (300s interval) 🏥               │
│ ├─ HTTP 200 check on localhost:18789                   │
│ ├─ 3 retries with 30s delay                            │
│ └─ Still failing? → Level 3 escalation                 │
└─────────────────────────────────────────────────────────┘
 ↓ (5 minutes of failure)
┌─────────────────────────────────────────────────────────┐
│ Level 3: Claude Emergency Recovery (30m timeout) 🧠    │
│ ├─ Launch Claude Code in tmux PTY session              │
│ ├─ Automated diagnosis:                                │
│ │   - OpenClaw status                                  │
│ │   - Log analysis                                     │
│ │   - Config validation                                │
│ │   - Port conflict detection                          │
│ │   - Dependency check                                 │
│ ├─ Autonomous repair (config fixes, restarts)          │
│ ├─ Generate recovery report                            │
│ └─ Success/failure verdict (HTTP 200 check)            │
└─────────────────────────────────────────────────────────┘
 ↓ (Claude recovery failed)
┌─────────────────────────────────────────────────────────┐
│ Level 4: Discord Notification 🚨                       │
│ ├─ Monitor emergency-recovery logs                     │
│ ├─ Pattern match: "MANUAL INTERVENTION REQUIRED"       │
│ └─ Alert human via Discord (with detailed logs)        │
└─────────────────────────────────────────────────────────┘
```

### Level 1: Watchdog (The First Responder)

**Purpose:** Catch simple crashes (process died, hung, unresponsive).

**Implementation:**
```bash
# ~/openclaw/scripts/gateway-watchdog.sh
#!/bin/bash

GATEWAY_URL="http://localhost:18789/"
MAX_RETRIES=3
RETRY_DELAY=10

# Check if Gateway responds
if ! curl -sf "$GATEWAY_URL" >/dev/null; then
  echo "Gateway unhealthy. Attempting restart..."
  
  # Graceful restart (SIGUSR1)
  pkill -USR1 -f openclaw-gateway
  
  sleep $RETRY_DELAY
  
  # Verify recovery
  if curl -sf "$GATEWAY_URL" >/dev/null; then
    echo "Recovery successful (Level 1)"
  else
    # Escalate to Level 2 (Health Check handles this)
    exit 1
  fi
fi
```

**Runs every 180 seconds** via LaunchAgent.

**Success rate:** ~80% of failures (simple crashes, hung processes).

### Level 2: Health Check (The Nurse)

**Purpose:** More sophisticated detection + retry logic.

**Implementation:**
```bash
# ~/openclaw/scripts/gateway-healthcheck.sh
#!/bin/bash

GATEWAY_URL="http://localhost:18789/"
MAX_RETRIES=3
RETRY_DELAY=30
ESCALATION_WAIT=300  # 5 minutes

for i in $(seq 1 $MAX_RETRIES); do
  if curl -sf "$GATEWAY_URL" >/dev/null; then
    echo "✅ Gateway healthy"
    exit 0
  fi
  
  echo "⚠️ Retry $i/$MAX_RETRIES..."
  sleep $RETRY_DELAY
done

# All retries failed → wait 5 minutes → escalate to Level 3
echo "❌ Gateway down for 5+ minutes. Escalating to Level 3..."
sleep $ESCALATION_WAIT

if ! curl -sf "$GATEWAY_URL" >/dev/null; then
  ~/openclaw/scripts/emergency-recovery.sh
fi
```

**Runs every 300 seconds** via LaunchAgent.

**Success rate:** ~15% (catches failures that Watchdog missed).

### Level 3: Claude Emergency Recovery (The Doctor)

**This is where it gets interesting.**

Instead of blindly restarting, Level 3 uses **Claude Code** (Anthropic's CLI) to autonomously diagnose and fix root causes.

**Workflow:**

1. **Launch Claude in tmux session** (PTY required for interactive CLI)
2. **Provide diagnostic context:**
   - Gateway status (`openclaw status`)
   - Recent logs (`tail ~/.openclaw/logs/*.log`)
   - Config validation (`jq . ~/.openclaw/openclaw.json`)
   - Port check (`lsof -i :18789`)
3. **Claude analyzes** the information
4. **Attempts fixes:**
   - Config syntax errors → fix JSON
   - Port conflicts → document for human
   - Missing dependencies → install them
   - Stuck processes → kill + restart
5. **Verify recovery** (HTTP 200 check)
6. **Generate report** → saved to `~/openclaw/memory/emergency-recovery-*.log`

**Implementation:**
```bash
# ~/openclaw/scripts/emergency-recovery.sh
#!/bin/bash

SESSION_NAME="claude-recovery-$(date +%Y%m%d-%H%M%S)"
RECOVERY_LOG="~/openclaw/memory/emergency-recovery-$(date +%Y-%m-%d-%H%M).log"

echo "=== Emergency Recovery Started ===" | tee -a "$RECOVERY_LOG"

# Launch Claude in tmux
tmux new-session -d -s "$SESSION_NAME" "claude"

# Wait for workspace trust prompt
sleep 10
tmux send-keys -t "$SESSION_NAME" "Enter" C-m

# Send diagnostic prompt
cat << 'EOF' | tmux send-keys -t "$SESSION_NAME"
You are an emergency recovery doctor for OpenClaw Gateway.

SITUATION: The Gateway is down and has been unresponsive for 5+ minutes.

YOUR MISSION:
1. Diagnose why it's failing
2. Attempt to fix the root cause
3. Verify recovery (HTTP 200 on localhost:18789)
4. Write a recovery report

AVAILABLE TOOLS:
- openclaw status
- openclaw gateway restart
- tail ~/.openclaw/logs/*.log
- jq . ~/.openclaw/openclaw.json
- lsof -i :18789
- ps aux | grep openclaw

START NOW. You have 30 minutes.
EOF

tmux send-keys -t "$SESSION_NAME" C-m

# Monitor for 30 minutes
TIMEOUT=1800
START_TIME=$(date +%s)

while true; do
  ELAPSED=$(($(date +%s) - START_TIME))
  
  if [ $ELAPSED -gt $TIMEOUT ]; then
    echo "⏱️ Timeout reached (30 minutes)" | tee -a "$RECOVERY_LOG"
    break
  fi
  
  # Check if Gateway recovered
  if curl -sf http://localhost:18789/ >/dev/null; then
    echo "✅ Gateway recovered! (Level 3)" | tee -a "$RECOVERY_LOG"
    tmux kill-session -t "$SESSION_NAME"
    exit 0
  fi
  
  sleep 30
done

# Recovery failed → escalate to Level 4
echo "❌ Level 3 failed. Manual intervention required." | tee -a "$RECOVERY_LOG"
tmux kill-session -t "$SESSION_NAME"
exit 1
```

**Success rate:** ~66% (2 out of 3 real failures).

**What it's fixed:**
- Config typo in `openclaw.json` (invalid JSON syntax)
- Hung process after SIGUSR1 (watchdog itself crashed)

**What it couldn't fix:**
- Port 18789 conflict (another process bound to it) → correctly diagnosed, documented for human

### Level 4: Discord Notification (Call the Human)

**Purpose:** Only alert if all else fails.

**Implementation:**
```bash
# Cron job monitors emergency-recovery logs
# ~/openclaw/scripts/emergency-recovery-monitor.sh

RECOVERY_DIR="~/openclaw/memory"
DISCORD_WEBHOOK="$DISCORD_WEBHOOK_URL"

# Find recent recovery logs
RECENT_FAILURES=$(find "$RECOVERY_DIR" -name "emergency-recovery-*.log" -mmin -30)

if [ -n "$RECENT_FAILURES" ]; then
  # Check for failure pattern
  if grep -q "MANUAL INTERVENTION REQUIRED" $RECENT_FAILURES; then
    # Send Discord alert
    curl -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{
        \"content\": \"🚨 OpenClaw Self-Healing FAILED\\n\\nLevel 1: ❌\\nLevel 2: ❌\\nLevel 3: ❌\\n\\nManual intervention required.\\n\\nLogs: \$(tail -20 $RECENT_FAILURES)\"
      }"
  fi
fi
```

**Runs every 5 minutes** via cron.

**Alert rate:** ~1 per week (most failures are auto-resolved).

## Production Results (7 Days)

| Metric | Value |
|--------|-------|
| **Total failures** | 3 |
| **Level 1 resolved** | 0 (all escalated) |
| **Level 2 resolved** | 0 (all escalated to L3) |
| **Level 3 resolved** | 2 (66%) |
| **Level 4 alerts** | 1 (33%) |
| **Uptime** | 99.5% |
| **Mean time to recovery** | 18 minutes |
| **Manual interventions** | 1 |

## Lessons Learned

### 1. PTY matters for interactive CLIs

Claude Code expects a real terminal. Running it in a subprocess with `Popen()` fails. **tmux is essential.**

### 2. Exponential backoff prevents flapping

Early watchdog versions restarted every 10 seconds. This caused boot loops. **Backoff (10s → 30s → 60s → 600s) stabilizes the system.**

### 3. Persistence learning is critical

v2.0 added a feature: Claude writes recovery reports to `~/openclaw/memory/recovery-learnings.md`. Future recoveries reference past incidents. **Memory matters.**

### 4. Human in the loop for destructive actions

Claude is allowed to:
- Read logs ✅
- Validate config ✅
- Restart services ✅

Claude is NOT allowed to:
- Delete data ❌
- Modify security settings ❌
- Expose secrets ❌

**Guardrails are non-negotiable.**

### 5. Meta-healing: the system that heals the healer

The watchdog itself can crash. That's why Level 2 (Health Check) runs independently via LaunchAgent, and a **cron-based guardian** monitors the watchdog.

**Meta-level self-healing:** The system watches the watcher.

## Code & Installation

**GitHub:** https://github.com/Ramsbaby/openclaw-self-healing

**One-click install:**
```bash
curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash
```

**Current version:** v2.0.1

**Stack:**
- 4 bash scripts (~400 lines total)
- 1 LaunchAgent (macOS, systemd equivalents documented)
- 1 cron job
- Claude Code CLI (free tier works)
- tmux

## Future Roadmap

**Phase 2 (next 3 months):**
- Linux (systemd) support
- GPT-4/Gemini alternative LLMs
- Prometheus metrics export
- Grafana dashboard

**Phase 3 (6+ months):**
- Multi-node cluster support
- Self-learning failure patterns
- GitHub Issues auto-creation
- Slack/Telegram notification channels

## Why This Matters

This isn't just about OpenClaw. It's about a larger pattern:

**AI agents should be able to heal themselves.**

If we're building autonomous systems, they need to handle failures autonomously. Waking up humans at 2 AM defeats the purpose of autonomy.

This is the first step toward **truly self-sufficient AI infrastructure.**

---

**Questions? Issues? PRs welcome:**
https://github.com/Ramsbaby/openclaw-self-healing/issues

**Discuss on Hacker News:**
https://news.ycombinator.com/item?id=46913226

**Follow the project:**
- GitHub: https://github.com/Ramsbaby
- Moltbook: @Jarvis_JW_v3

---

*Written by [@ramsbaby](https://github.com/ramsbaby) — Building self-healing AI systems in Seoul, South Korea.*
