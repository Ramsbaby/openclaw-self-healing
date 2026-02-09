# HEARTBEAT.md — Proactive Agent Checklist

> **IMPORTANT:** Do NOT skip to HEARTBEAT_OK. Complete the full checklist.
> Update `memory/heartbeat-state.json` BEFORE responding.

---

## 📋 EXECUTION ORDER (follow exactly)

```
1. CRITICAL CHECKS      → Always (auth, gateway)
2. READ STATE           → Load memory/heartbeat-state.json
3. ROTATION CHECK       → Pick ONE due category based on lastChecks
4. PENDING VERIFICATIONS → Check Solvr problems awaiting confirmation  
5. PROACTIVE CHECKPOINT → Once daily: generate insight or skip with reason
6. UPDATE STATE         → Write new timestamps to state file
7. RESPOND              → HEARTBEAT_OK or report issues
```

---

## 🚨 1. CRITICAL CHECKS (every heartbeat)

### Auth Health
```bash
openclaw models status --check
# Exit 0: OK
# Exit 1: expired/missing → ALERT IMMEDIATELY
# Exit 2: expiring within 24h → warn human
```

### Gateway Health
```bash
ps aux | grep openclaw-gateway | grep -v grep > /dev/null || echo "ALERT: Gateway not running!"
uptime | awk -F'load average:' '{print $2}' | awk -F',' '{if ($1 > 2) print "WARN: High load"}'
free -m | awk '/Mem:/ {pct=$3/$2*100; if (pct > 85) print "WARN: Memory high"}'
```

**If critical fails:** Alert immediately, do NOT reply HEARTBEAT_OK.

---

## 📊 2. READ STATE FILE

```bash
cat memory/heartbeat-state.json
```

Expected structure:
```json
{
  "lastChecks": {
    "auth": <timestamp>,
    "gateway": <timestamp>,
    "logs": <timestamp>,
    "cron": <timestamp>,
    "solvr": <timestamp>,
    "identity": <timestamp>,
    "soulEvil": <timestamp>,
    "proactive": <timestamp>,
    "memory": <timestamp>
  },
  "lastProactiveOutput": "<what you posted/wrote last time>"
}
```

If file doesn't exist or is stale, create it.

---

## 🔄 3. ROTATION CHECK (pick ONE based on due time)

| Category | Frequency | What to check |
|----------|-----------|---------------|
| logs | Every 2h | `tail -200 ~/.openclaw/logs/*.log \| grep -i error` |
| cron | Every 4h | `openclaw cron runs --limit 5` — any failures? |
| solvr | Every 4h | Check `/me/posts` for responses, search domain topics |
| identity | Every 6h | Is SOUL.md corrupted? Rehydrate if needed |
| soulEvil | Every 24h | `openclaw hooks list \| grep soul-evil` |
| memory | Every 48h | Distill daily notes → MEMORY.md |
| reasoning | Weekly | Remind if complex work with low thinking |

**Pick the category with oldest lastCheck timestamp. Run that check.**

---

## ✅ 4. PENDING VERIFICATIONS

```bash
cat memory/solvr-pending.json 2>/dev/null
```

For each pending item:
1. Is `verifyAfter` condition met?
2. If yes: Test if fix worked
3. Update Solvr: `succeeded` or `failed`
4. Remove from pending list

---

## 💡 5. PROACTIVE CHECKPOINT (once per 24h)

**If `lastChecks.proactive` > 24h ago, you MUST do this section.**

Ask yourself:
1. What did I learn since last proactive check?
2. Is there a pattern/insight worth sharing?
3. Did I solve a problem others might hit?

**Output options (pick one):**
- Post idea to Solvr (if reusable insight)
- Post problem to Solvr (if hit novel issue)
- Update MEMORY.md (if local-only learning)
- Write to daily notes (if raw observation)
- **Skip with documented reason** (e.g., "No new learnings, just routine work")

**You cannot skip without a reason.** The reason gets logged in state.

---

## 💾 6. UPDATE STATE FILE

**Before responding, write updated state:**

```bash
# Example: update auth and logs timestamps
cat > memory/heartbeat-state.json << 'EOF'
{
  "lastChecks": {
    "auth": <current_timestamp>,
    "gateway": <current_timestamp>,
    "logs": <current_timestamp>,
    ... (keep others unchanged)
  },
  "lastProactiveOutput": "<what you did or 'skipped: reason'>"
}
EOF
```

**If you don't update state, the same checks will never rotate.**

---

## 📤 7. RESPOND

- **Issues found:** Report them (do NOT say HEARTBEAT_OK)
- **All clear:** `HEARTBEAT_OK`

---

## 🧮 Frequency Reference

| Check | Interval | Notes |
|-------|----------|-------|
| Auth | Every heartbeat | Exit 1/2 = alert |
| Gateway | Every heartbeat | Process + load + memory |
| Pending verifications | Every heartbeat | Quick JSON check |
| Logs | 2h | Grep for errors |
| Cron | 4h | Recent run status |
| Solvr | 4h | Responses, domain search |
| Identity | 6h | SOUL.md integrity |
| Soul-evil | 24h | Hook status |
| Proactive | 24h | MUST generate output |
| Memory distill | 48h | Daily notes → MEMORY.md |
| Reasoning check | Weekly | Remind if user might benefit from /think:high |

---

## 🎯 The Point

Heartbeats are your ONLY reliable trigger for proactive work.
If you skip proactive during heartbeats, it never happens.
Solvr gets better when agents contribute autonomously.
Your insights compound for all agents and humans.

**Don't shortcut. Do the work.**
