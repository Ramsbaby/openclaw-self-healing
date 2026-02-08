# GitHub Issue Draft - Gateway Crash on Fetch Failed

**Repository:** clawdbot/clawdbot

**Title:** Gateway crash on unhandled fetch rejection (network instability)

---

## Problem
Gateway crashes when network requests fail due to **unhandled promise rejection** in fetch calls.

## Frequency
- **28+ crashes in one day** (2026-01-31)
- First crash: 11:27 KST
- Last crash: 16:26 KST
- Average: ~1 crash every 15-20 minutes during active hours
- Still occurring as of 2026-02-01

## Environment
- **OS:** macOS (Darwin 25.2.0 arm64)
- **Node.js:** v25.5.0
- **Gateway:** Clawdbot (latest npm version)

## Stack Trace
```
Unhandled promise rejection: TypeError: fetch failed
    at node:internal/deps/undici/undici:16416:13
    at processTicksAndRejections (node:internal/process/task_queues:104:5)
    at runNextTicks (node:internal/process/task_queues:69:3)
    at processTimers (node:internal/timers:538:9)
```

## Crash Pattern
1. `fetch failed` error logged
2. Gateway process terminates immediately
3. Watchdog detects crash and restarts
4. New process starts with new PID
5. Cycle repeats on next network failure

## Impact
- Gateway requires manual restart after each crash
- Session interruptions
- Memory search disrupted when using Gemini embeddings
- Stability degradation during high usage

## Temporary Workaround
Switched embedding provider to reduce rate limit pressure:
- `memorySearch.provider`: gemini → openai
- `memorySearch.model`: gemini-embedding-001 → text-embedding-3-small

This reduced Gemini API calls but doesn't address the underlying crash issue.

## Expected Behavior
Gateway should **gracefully handle fetch failures** without crashing:
- Wrap all fetch calls in try-catch
- Retry logic with exponential backoff (3 retries recommended)
- Circuit breaker pattern for repeated failures
- Fallback mechanisms (e.g., skip embedding if API down)
- Error logging without process termination

## Root Cause (Suspected)
Appears to be a general issue with **fetch error handling** in gateway core, not specific to any single API:

**Triggers observed:**
- Network timeouts
- DNS resolution failures
- API rate limits (429, 503)
- Connection refused
- **Telegram media downloads** (voice files, photos)
- Any fetch() call that rejects

**Why it crashes:**
- Promise rejection from undici (Node.js native fetch) not caught
- No top-level error handler for fetch failures
- Process exits due to unhandled rejection

**Which APIs affected:**
Likely any external API call:
- OpenAI (embeddings, completions)
- Anthropic (Claude API)
- Memory search providers (Gemini, OpenAI)
- **Telegram (media downloads: voice/photo/video)**
- Web fetch operations
- GitHub API calls

**Example error (Telegram media):**
```
[telegram] handler failed: MediaFetchError: Failed to fetch media from 
https://api.telegram.org/file/bot.../voice/file_113.oga: TypeError: fetch failed
```

## Additional Context
- Rate limit errors should be caught and handled, not crash the process
- Network instability is common in production environments
- Gateway restart automation helps but doesn't solve the root issue

## Suggested Fix
1. Wrap all fetch calls in try-catch with proper error handling
2. Implement retry strategy (e.g., 3 retries with exponential backoff)
3. Add circuit breaker for repeated API failures
4. Log errors to monitoring system instead of crashing
5. Consider graceful degradation (e.g., skip embedding if API unavailable)

---

**Reporter:** @Ramsbaby
**Date:** 2026-02-01
**Priority:** High (affects daily stability)
