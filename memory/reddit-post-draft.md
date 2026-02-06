# Reddit r/selfhosted 게시문 초안

## Title
[Project] Self-Healing System for AI Agents - Uses Claude Code as Emergency Doctor

## Body
**TL;DR:** Built a 4-tier watchdog system that can autonomously diagnose and fix crashes using AI.

---

## The Problem
Running AI agents (OpenClaw, similar to n8n but for AI) means dealing with random crashes at 3am. Traditional watchdogs just restart - they don't understand *why* things broke.

## The Solution
4-tier escalation system:

| Level | Trigger | Action |
|-------|---------|--------|
| 1 | Process dead | Restart (180s) |
| 2 | HTTP unhealthy | Retry 3x, then escalate (300s) |
| 3 | L2 failed | Launch Claude Code in tmux, diagnose, fix (30min) |
| 4 | L3 failed | Discord alert to human |

## The Interesting Part
Level 3 launches Claude Code (Anthropic's CLI) in a tmux PTY session. It:
- Reads system logs
- Analyzes error patterns  
- Identifies root cause
- Executes fixes autonomously
- Reports results

All logged. All auditable. 30-minute timeout for human intervention.

## Security
- Isolated tmux session
- Cannot access main credentials
- Read-only config access
- Cleanup trap prevents orphans

## Links
- GitHub: https://github.com/Ramsbaby/openclaw-self-healing
- Demo GIF in README

Would love feedback from the self-hosted community. Anyone else running AI agents 24/7?
