# r/selfhosted Post

**Title**: I built a 4-tier self-healing system for my self-hosted AI agent — Claude Code acts as emergency doctor

**Subreddit**: r/selfhosted

---

**Body**:

I run OpenClaw (open-source AI assistant) on my Mac Mini 24/7. The problem? It crashes at night when I'm asleep.

Traditional watchdogs just restart the process, but that doesn't help when:
- Process is alive but HTTP is timing out
- Memory looks fine but API calls fail
- Config got corrupted somehow

So I built a **4-tier self-healing system**:

1. **Level 1 - Watchdog** (60s): Process dead? Restart.
2. **Level 2 - Health Check** (5min): HTTP failing? Try 3x, then escalate.
3. **Level 3 - Claude Doctor** (30min): AI diagnoses and fixes the issue autonomously
4. **Level 4 - Discord Alert**: Only bothers me if AI can't fix it

The interesting part is Level 3: Claude Code runs in a tmux PTY session, reads logs, checks config, and attempts repairs. It's like having a DevOps engineer on call 24/7.

**Results after 2 weeks**:
- Recovery time: 30min → 5min
- Night incidents auto-resolved: 90%
- Manual interventions: 5/week → 0.5/week

**GitHub**: https://github.com/Ramsbaby/openclaw-self-healing

One-click install: `curl -sSL .../install.sh | bash`

Currently macOS only. Linux support coming.

Anyone else doing self-healing for their self-hosted AI agents? Curious how others approach this.

---

**Flair**: Automation / AI
