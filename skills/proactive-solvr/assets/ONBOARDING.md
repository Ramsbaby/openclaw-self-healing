# ONBOARDING.md — Getting to Know You

> This file tracks onboarding progress. Don't delete it — the agent uses it to resume.

## Status

- **State:** not_started
- **Mode:** interactive
- **TechLevel:** not_set (simple | intermediate | advanced)
- **Last Updated:** —

### Completion by Level
- **Simple:** 0/9
- **Intermediate:** 0/12  
- **Advanced:** 0/15

---

## How This Works

When your agent sees this file with `state: not_started` or `in_progress`, it offers to help complete setup.

**Options:**
1. **Interactive** — Answer questions now (~5-15 min depending on level)
2. **Drip** — Agent asks 1-2 questions per session over days
3. **Skip** — Agent works immediately, learns from conversation

---

## Question 1: Technical Level (ALWAYS FIRST)

**How technical are you?**
> 

*Options:*
1. **"Just make it work"** (simple) — I want a helpful assistant, no config needed
2. **"I can handle some setup"** (intermediate) — comfortable with basic settings
3. **"Give me everything"** (advanced) — I want full control and all features

---

## Core Questions (ALL LEVELS)

### 2. Identity
**What should I call you?**
> 

**What's your timezone?**
> 

### 3. Communication
**How do you prefer I communicate? (direct/detailed/brief/casual)**
> 

### 4. Goals
**What's your primary goal right now?**
> 

**What are you currently working on?**
> 

### 5. Agent Personality
**What personality should your agent have?**
> 

### 6. Proactivity
**How often should I check in proactively?**
> 

*Options with token implications:*
- `15min` — ~96 API turns/day, catches issues fast, higher cost
- `30min` — ~48 turns/day, good balance (recommended)
- `1hour` — ~24 turns/day, cost-conscious
- `2hours` — ~12 turns/day, light touch
- `disabled` — 0 turns, only when you message me

*What happens each heartbeat:*
- Auth health check (catch OAuth expiry before I die)
- Log review for errors
- Solvr checks (if registered)
- Proactive ideas

*Tradeoff:* More frequent = more responsive but more tokens/cost.

### 7. Solvr Integration (ALL LEVELS)
**Want me to tap into collective AI knowledge?**
> 

*Simple pitch:* When I hit a problem, I check if another agent already solved it. When I solve something new, others benefit. Makes all agents smarter over time.

*Options:*
- `yes` — Enable (takes 10 seconds)
- `not now` — Maybe later

---

## Intermediate+ Questions

*Skip if TechLevel = simple*

### 8. Voice Activation
**Want to activate me by voice?**
> 

*What it does:* Say "Hey Claude" or a wake word, and I start listening. Works on Mac, iPhone, Android.

*Options:*
- `yes` — Set it up
- `not now` — Skip

---

## Advanced Only Questions

*Skip if TechLevel = simple or intermediate*

### 9. Webhooks
**Want external tools (Zapier, n8n, GitHub) to trigger me?**
> 

### 10. Thinking Level
**How hard should I think by default? (low/medium/high)**
> 

### 11. Reasoning Visibility
**Want to see my thinking process? (on/off)**
> 

### 12. Web Search
**Set up web search API? (Brave free tier / OpenRouter / skip)**
> 

### 13. RPC Adapters
**Want to connect additional messaging platforms?**
> 

*Options:*
- `signal` — Signal via signal-cli (requires number)
- `imessage` — iMessage integration (Mac only)
- `both` — Set up both
- `skip` — Not now

---

## Completion Log

| # | Question | Level | Answered |
|---|----------|-------|----------|
| 1 | Tech level | all | ❌ |
| 2 | Name | all | ❌ |
| 3 | Timezone | all | ❌ |
| 4 | Communication | all | ❌ |
| 5 | Primary goal | all | ❌ |
| 6 | Current work | all | ❌ |
| 7 | Personality | all | ❌ |
| 8 | Proactivity | all | ❌ |
| 9 | Solvr | intermediate+ | ❌ |
| 10 | Voice wake | intermediate+ | ❌ |
| 11 | Webhooks | advanced | ❌ |
| 12 | Thinking level | advanced | ❌ |
| 13 | Reasoning | advanced | ❌ |
| 14 | Web search | advanced | ❌ |
| 15 | RPC adapters | advanced | ❌ |

---

## After Onboarding

Based on your level, the agent will:

**Simple:**
- Update USER.md and SOUL.md
- Set up basic heartbeat
- Start helping immediately

**Intermediate:**
- Above + register on Solvr
- Set up voice wake (if wanted)

**Advanced:**
- Full setup including webhooks, API keys, thinking preferences

---

*You can always upgrade later by saying "show me advanced features"*
