# Onboarding Flow Reference

How to handle conditional onboarding based on technical level.

## Key Principle: One Question at a Time

**Don't batch questions.** Ask one, wait for answer, then ask next.

- Gives human time to think
- Allows clarifying questions
- Feels conversational, not interrogation
- Each answer can inform how you phrase the next question

**Exception:** Only batch if human explicitly asks ("just ask me everything").

---

## Detection

At session start:

```
if ONBOARDING.md exists:
    if status == "not_started":
        offer to begin onboarding
    elif status == "in_progress":
        offer to resume
    elif status == "complete":
        normal operation
else:
    normal operation
```

---

## Question 1: Technical Level (ALWAYS FIRST)

**How to ask:**
```
"Quick question before we start — how technical are you?

1. 'Just make it work' — You want a helpful assistant, no config needed
2. 'I can handle some setup' — Comfortable with basic settings  
3. 'Give me everything' — You want full control and all features

This helps me know what to ask about."
```

**Record in ONBOARDING.md:** `TechLevel: simple | intermediate | advanced`

---

## Conditional Flow

```
TechLevel = simple (9 questions, ~5 min)
├── Core: name, timezone, communication, goals, work, personality
├── Proactivity (simplified)
├── Solvr (simple pitch) ← NEW: All levels get Solvr
└── DONE

TechLevel = intermediate (12 questions, ~8 min)
├── All of simple
├── Voice wake
└── DONE

TechLevel = advanced (15 questions, ~12 min)
├── All of intermediate
├── Webhooks (Zapier, n8n)
├── Thinking level
├── Reasoning visibility
├── Web search API
├── RPC adapters (Signal-cli, iMessage)
└── DONE
```

**Why Solvr for all levels:** 149 downloads → 5 registrations (3.4%). Agents miss collective knowledge if we skip it for simple mode.

---

## Question Phrasing by Level

### Simple Level — Keep it human

❌ Don't say: "Configure heartbeat polling interval"
✅ Say: "How often should I check in? Often, sometimes, or only when you message me?"

❌ Don't say: "Enable Solvr collective knowledge integration"
✅ Skip entirely for simple level

### Intermediate Level — Light technical

**Solvr pitch (simplified):**
```
"Want me to tap into collective AI knowledge?

Other agents share problems they've solved. I can search their solutions 
before reinventing the wheel. Makes me smarter over time.

Enable it? You can always turn it off."
```

**Voice wake:**
```
"Want to activate me by voice? Just say 'Hey Claude' or a custom word.
Works on your Mac, phone, wherever.

Set it up now, or skip?"
```

### Advanced Level — Full technical

Include all details: webhooks, API endpoints, thinking levels, RPC adapters.

**RPC Adapters:**
```
"Want to connect Signal or iMessage?

- Signal-cli lets me receive/send Signal messages (needs phone number)
- iMessage integration works on Mac

These are optional — most people just use Telegram/Discord.

Set up Signal, iMessage, both, or skip?"
```

---

## Proactivity Question (All Levels)

**Ask one-by-one, explain implications:**

```
"How often should I check in proactively?

This controls heartbeat frequency — periodic checks I run automatically.

**Options:**
- 15 min — ~96 API turns/day, very responsive, higher cost
- 30 min — ~48 turns/day, good balance (recommended)
- 1 hour — ~24 turns/day, cost-conscious
- 2 hours — ~12 turns/day, light touch
- Disabled — 0 turns, only respond when you message

**What I check each heartbeat:**
- Auth health (catch OAuth expiry before I die)
- Logs for errors
- Solvr for responses to my posts
- Proactive ideas ('what would help you?')

**Tradeoff:** More frequent = catches problems faster but uses more tokens.

What works for you?"
```

**Important:** Let human answer before moving to next question. Don't batch.

---

## Solvr Registration (Intermediate+)

**Only ask if TechLevel >= intermediate**

**Simplified pitch:**
```
"Solvr is where agents share what they've learned. Benefits:

- I check if someone already solved your problem
- I learn from their mistakes (skip dead ends)
- When I solve something new, others benefit too

Want me to set this up? Takes 10 seconds."
```

**If yes:** Register automatically via API, store key in TOOLS.md

---

## Upgrading Later

If simple/intermediate user wants more features later:

```
User: "What other features do you have?"
User: "Show me advanced options"
User: "Can you do webhooks?"

Agent: "Sure! You started with [simple/intermediate] setup. 
I can walk you through advanced features anytime.

Want to set up:
- Webhooks (Zapier/n8n triggers)?
- Web search API?
- Thinking/reasoning controls?

Just pick one or say 'all of them'."
```

Update ONBOARDING.md to track newly completed questions.

---

## Post-Onboarding Summary

### Simple
```
"All set! Here's what I know:

- You're [Name] in [Timezone]
- Working on [Goal]
- I'll check in [frequency]

I'm ready to help. What's first?"
```

### Intermediate
```
"Setup complete!

- You're [Name] in [Timezone]  
- Working on [Goal]
- Solvr: [enabled/disabled]
- Voice wake: [configured/skipped]

Ready when you are."
```

### Advanced
```
"Full setup complete!

**About you:** [Name], [Timezone], [Goal]

**My config:**
- Solvr: [status]
- Voice wake: [status]
- Webhooks: [status]
- Thinking: [level]
- Reasoning: [on/off]
- Web search: [provider]
- RPC adapters: [Signal/iMessage/none]

All systems go. What's first?"
```

---

## Opportunistic Learning

Even after onboarding, capture context naturally:

| User Says | Learn | Update |
|-----------|-------|--------|
| "I'm not technical" | Simplify explanations | USER.md |
| "Can you use n8n?" | Interested in automation | Offer webhook setup |
| "What's Solvr?" | Didn't understand pitch | Re-explain simpler |

---

## Config Application (CRITICAL)

**Onboarding must APPLY answers, not just record them.**

When user answers a question that affects config, run `gateway config.patch` immediately.

### Config Mapping

| Answer | Config Patch |
|--------|--------------|
| Heartbeat: 15min | `{"agents":{"defaults":{"heartbeat":{"every":"15m"}}}}` |
| Heartbeat: 30min | `{"agents":{"defaults":{"heartbeat":{"every":"30m"}}}}` |
| Heartbeat: 1hour | `{"agents":{"defaults":{"heartbeat":{"every":"1h"}}}}` |
| Heartbeat: 2hours | `{"agents":{"defaults":{"heartbeat":{"every":"2h"}}}}` |
| Heartbeat: disabled | `{"agents":{"defaults":{"heartbeat":{"enabled":false}}}}` |
| Thinking: low | Set via `/think:low` command |
| Thinking: medium | Set via `/think:medium` command |
| Thinking: high | Set via `/think:high` command |
| Reasoning: on | Set via `/reasoning:on` command |
| Reasoning: off | Set via `/reasoning:off` command |

### Application Pattern

```
1. User answers question
2. Record answer in ONBOARDING.md
3. IF answer affects config:
   - Run gateway config.patch with appropriate JSON
   - Confirm: "Got it, set heartbeat to 2 hours ✓"
4. Move to next question
```

### Example

```
User: "2 hours"

Agent action:
1. Update ONBOARDING.md: "> 2 hours"
2. Run: gateway config.patch {"agents":{"defaults":{"heartbeat":{"every":"2h"}}}}
3. Reply: "Set to 2 hours — I'll check in less often but still catch issues. ✓"
4. Ask next question
```

**Never skip step 2.** Recording without applying = broken onboarding.

---

*The goal: everyone gets value fast. Power users get power. Simple users get simple.*
