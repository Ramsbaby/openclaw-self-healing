# Hacker News "Show HN" 게시문 초안

## Title (80자 이내)
Show HN: Self-Healing System for AI Agents – Claude Code as Emergency Doctor

## URL
https://github.com/Ramsbaby/openclaw-self-healing

## Text (선택적 - URL만 있어도 됨)
I built a 4-tier autonomous recovery system for OpenClaw Gateway (AI agent framework).

The interesting part: Level 3 uses Claude Code as an "emergency doctor" - it launches in a tmux PTY, reads logs, diagnoses issues, and autonomously fixes them.

Architecture:
- Level 1: Process watchdog (180s)
- Level 2: HTTP health check (300s)  
- Level 3: Claude Code diagnosis + repair (30min timeout)
- Level 4: Discord alert (human escalation)

Key insight: If we trust AI to write code, why not trust it to fix infrastructure? The AI already knows how to diagnose - we just gave it permission to act.

All actions are logged and auditable. 30-minute timeout ensures humans can intervene.

MIT licensed, bash scripts only, works on macOS (Linux guide included).

Would love feedback on the security model - how do you prevent the "doctor" from weakening its own checks?
