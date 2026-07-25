# Changelog

All notable changes to OpenClaw Self-Healing System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Fixed
- **install.sh / install-linux.sh** — script download base URL pointed at
  `$REPO_RAW/skills/openclaw-self-healing/scripts`, which returns 404. Scripts live at
  `$REPO_RAW/scripts`. Combined with `curl -sSL` (no `-f`), every download silently wrote
  a 404 HTML body to disk as a "script" and the installer still declared success. Now uses
  the correct base URL, `curl -fsSL`, and aborts with a non-zero exit on any failed download.
- **install.sh / install-linux.sh** — `gateway-preflight.sh` (Level 0), `lib/notify.sh` and
  `lib/llm-gateway.sh` were documented but never downloaded. They are now installed.
- **scripts/gateway-preflight.sh** — the file had been committed base64-encoded since it was
  introduced, so Level 0 could never run (`command not found` on the single encoded line).
  Restored to plain shell. This also brings it under ShellCheck coverage, which previously
  skipped it via the "not a shell script" branch in `.github/workflows/shellcheck.yml`.
- **install.sh** — prerequisite step printed `[1/6]` while the remaining seven steps printed
  `[n/8]`; `install-linux.sh` printed `[1/7]` against `[n/9]`.
- **launchagent/com.openclaw.healthcheck.plist** — `ProgramArguments` pointed at
  `$HOME/openclaw/scripts/`, but installers place scripts under
  `$HOME/.openclaw/skills/openclaw-self-healing/scripts/`.

### Changed
- **emergency-recovery.sh** — Level 3 LLM prompt now includes a "MANDATORY FIRST STEPS"
  block requiring Read tool calls (README.md / `~/.openclaw/openclaw.json` / recent logs /
  watchdog scripts) **before** diagnosis. Reduces hallucination risk where Claude attempts
  recovery without first reading actual system state. The prompt also asks Claude to log
  the Read tool invocation count to the report file for post-incident audit.
- **install.sh** — `--dry-run` output now lists every script that is actually downloaded,
  and reports Level 0 as `SCRIPT INSTALLED` and Level 1 as `PROVIDED BY GATEWAY` rather
  than `READY`. Neither level is scheduled by the installer.
- **.env.example** — added `SLACK_WEBHOOK_URL` and `NOTIFICATION_CHANNEL` (both consumed by
  `lib/notify.sh`; `NOTIFICATION_CHANNEL` is also read by `docker-compose.yml`), plus
  `OPENCLAW_METRICS_PORT` and `HEALTH_CHECK_HTTP_TIMEOUT`. Header version synced to 3.4.
- **SKILL.md** — version synced to 3.4.0; script table and setup steps corrected to the
  paths the installers actually use.
- **README.md / README.ko.md** — full rewrite for accuracy. Fixed broken links to
  `docs/configuration.md` and `docs/architecture.md` (neither file exists), unified the
  "4-tier"/"5-Tier" naming to five levels (0–4), corrected the watchdog backoff sequence to
  `10s → 30s → 90s → 180s → 300s → 600s` (300 was missing), replaced the invented installer
  transcript with real output, and added a "Known Gaps" section documenting the Level 2
  alert path, the unwired LLM router, the hardcoded Claude binary path, and the
  `validate-deployment.sh` path mismatch.

---

## [3.4.0] - 2026-03-25

### Added
- **Unified multi-channel notification library** (`scripts/lib/notify.sh`) — one
  `send_notification "title" "body" "level"` entry point dispatching to Discord, Slack or
  Telegram. Channel is forced via `NOTIFICATION_CHANNEL` or auto-detected from whichever
  webhook variable is set. (#3)
- **Docker Compose support** — `docker-compose.yml` runs `openclaw-gateway` plus a
  `self-healing-watchdog` sidecar that starts only once the gateway healthcheck passes.
  Guide in `docs/DOCKER.md`. (#1)
- **`--dry-run` mode for install.sh** — previews directories, downloads, environment file
  and LaunchAgents without writing anything.
- **Weekly incident digest** (`scripts/incident-digest.sh`) — Markdown summary of the last
  7 days with autonomy rate; `--discord` posts it to the configured channel.
- **CI syntax lint** (`.github/workflows/lint.yml`) — `bash -n` across every `.sh` file.
- **Korean README** (`README.ko.md`) and a language badge on the English README.
- **Architecture and hero SVG diagrams** under `docs/assets/`.

### Changed
- **gateway-healthcheck.sh** — replaced its Discord-only sender with `lib/notify.sh`,
  falling back to a no-op when the library is absent.

### Fixed
- **emergency-recovery-v2.sh** — the committed file was base64-encoded and unrunnable;
  replaced with clean v2.1.0 source.

---

## [3.3.0] - 2026-03-18

### Added
- **LLM-agnostic recovery layer** (`scripts/lib/llm-gateway.sh`) — `ask_llm()` wrapper
  supporting Claude Code CLI, OpenAI (`gpt-4o`), Google Gemini (`gemini-2.0-flash`) and
  Ollama (`llama3.2`), selected via `OPENCLAW_LLM_PROVIDER` with optional
  `OPENCLAW_LLM_MODEL` override.
  **Note:** the library ships but is not yet called by any recovery script — Level 3 still
  drives the Claude Code CLI directly. See "Known Gaps" in the README.
- **Prometheus metrics exporter** (`scripts/prometheus-exporter.py`,
  `scripts/start-metrics-exporter.sh`) — eight gauges on `:9090/metrics`, port overridable
  via `OPENCLAW_METRICS_PORT`. Subcommands: `start`, `stop`, `restart`, `status`.

### Changed
- **.env.example** — added the LLM provider configuration block.
- **README.md** — added a recovery-rate badge and an OpenClaw Gateway description.

---

## [3.2.0] - 2026-03-11

### Added
- **Level 0: Preflight validation** (`scripts/gateway-preflight.sh`) — validates the
  gateway binary, `node`, `.env` presence and required keys, and every JSON config before
  the gateway starts, then backs up known-good configs and `exec`s the gateway so launchd
  and systemd keep tracking the real PID. On failure it opens a `tmux` AI recovery session
  and backs off 30s → 90s → 180s, capped at `MAX_PREFLIGHT_ATTEMPTS=3` with a 6-hour
  counter reset.

### Fixed
- **emergency-recovery-v2.sh** — `ANTHROPIC_API_KEY` was silently missing inside `tmux`
  sessions spawned from launchd, because those sessions do not inherit the launchd
  environment. The key is now forwarded explicitly via `tmux -e`.
- **ShellCheck CI** — resolved SC2155 / SC2034 / SC2064 / SC2015 warnings across all scripts.

### Changed
- **gateway-watchdog.sh v4.2** — runs `openclaw doctor --fix` automatically after repeated
  `exit_1` crashes, so a config schema mismatch after a version bump self-repairs instead of
  causing permanent paralysis. Guarded by `CONFIG_FIX_COUNTER` at a maximum of 2 attempts. (#7)

---

## [3.1.0] - 2026-02-21

### Fixed
- **Level 2→3 Chain Disconnection** — Watchdog now auto-escalates to Emergency Recovery after 30min of continuous failure (was completely disconnected)
- **Discord Webhook Never Set** — emergency-recovery-v2.sh now reads `DISCORD_WEBHOOK_URL` from `~/.openclaw/.env` with graceful fallback if not configured
- **Installer Only Set Up Level 2** — Complete chain now installed out of the box

### Changed
- **gateway-watchdog.sh v4.1** — Added `check_level3_escalation()` and `trigger_level3_emergency_recovery()` functions; critical failure tracking with configurable 30min threshold
- **gateway-healthcheck.sh** — Fixed escalation path to emergency-recovery-v2.sh; improved .env loading
- **emergency-recovery-v2.sh** — Prioritized `~/.openclaw/.env` over `~/openclaw/.env`; logs when no webhooks configured instead of failing silently
- **install.sh** — Complete rewrite: sets up full 4-tier chain (Watchdog LaunchAgent with `StartInterval` only — no `KeepAlive`), interactive .env generation, auto-detects gateway token, verification step
- **install-linux.sh** — Complete rewrite: systemd-based setup with timer units, interactive configuration, verification
- **.env.example** — Added Watchdog configuration variables, gateway port/token, Level 3 escalation timing
- **README.md** — Updated architecture diagram to reflect actual Level 1→2→3→4 chain with accurate timing and trigger conditions

### Removed
- LaunchAgent `KeepAlive` + `StartInterval` conflict (2/7 incident lesson)

---

## [2.1.0] - 2026-02-09

### Added
- **Emergency PTY Recovery Auto-Trigger** — Level 3 now automatically triggers when Watchdog detects critical failures (crash >= 5 OR doctor --fix fails 2x)
- **config-watch Auto-Repair** — Proactive config validation with automatic `doctor --fix` on schema violations (~2min recovery)
- **Enhanced 4-Tier Self-Healing** — config-watch (L1) → Watchdog (L2) → Emergency PTY (L3) → Guardian + Discord (L4)

### Changed
- **Watchdog v5.4** — Now triggers Emergency Recovery instead of giving up on critical failures
- **config-watch** — Enhanced with JSON validation + auto-repair (previously backup-only)
- **Architecture** — Maintained 4-tier structure, added config-watch as new L1, Emergency PTY as L3

### Fixed
- **Critical Bug**: Emergency Recovery script existed but was never automatically triggered (fixed by adding Watchdog integration)
- **Recovery Gap**: No automatic escalation path from Watchdog to Claude autonomous recovery

### Performance
- **Config errors**: Now recover in ~2min (down from manual intervention)
- **Complex failures**: Auto-trigger Claude recovery (previously required manual script execution)

### Documentation
- Updated README.md with new 3-tier architecture diagram
- Added recovery path examples
- Updated "What Makes This Special" section with v2.1 features

### Technical Details
- `gateway-watchdog.sh`: Added Emergency Recovery trigger at 3 critical failure points
- `config-watch.sh`: Added `doctor --check` + `doctor --fix` auto-execution
- Both scripts now send Discord alerts on auto-repair success/failure

---

## [2.0.2] - 2026-02-09

### Added
- **Watchdog v5.3 - Auto Config Fix**: Automatic `openclaw doctor --fix` execution when crash_count >= 2
  - Detects configuration validation errors automatically
  - Reduces recovery time from 36 minutes to 7 minutes (5x faster)
  - No separate cron required (integrated into Watchdog LaunchAgent)
  - Maintains full backward compatibility with existing functionality

### Improved
- **Gateway Recovery**: Enhanced self-healing system with configuration auto-fix
- **Alerting**: Discord notifications now include auto-fix attempt information
- **Documentation**: Added detailed version history for Watchdog v5.3

### Technical Details
- **Trigger condition**: crash_count >= 2 (5+ minutes of continuous failure)
- **Action**: Execute `openclaw doctor --fix` to repair configuration errors
- **Fallback**: If auto-fix fails, continues with standard restart retry logic
- **Risk**: Minimal (code changes isolated, easy rollback via git revert)

## [2.0.1] - 2026-02-07

### Fixed
- **Reasoning log extraction:** Claude's reasoning process (Decision Making, Lessons Learned) is now properly extracted and appended to `recovery-learnings.md` (#Critical)
- **Version consistency:** Script header version unified to v2.0.0 across all files
- **Environment variable naming:** `DISCORD_WEBHOOK_URL` consistency improved in `emergency-recovery-v2.sh`
- **ShellCheck warnings:** `read -r` flag added to `metrics-dashboard.sh` (SC2162)

### Improved
- **Edge case handling:** Graceful fallback when reasoning log file is missing
- **Code quality:** ShellCheck recommendations applied

## [2.0.0] - 2026-02-07

### Added
- **Recovery Documentation**: Persistent learning repository (`recovery-learnings.md`)
  - Automatically extracts symptom, root cause, solution, and prevention from each recovery
  - Cumulative knowledge base for future incidents
  - Addresses Moltbook ContextVault feedback
- **Reasoning Logs**: Separate reasoning process logs (`claude-reasoning-*.md`)
  - Captures Claude's decision-making process
  - Explainability and transparency
  - Helps understand why specific fixes were chosen
- **Telegram Alert Support**: Alternative notification channel
  - Configure via `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`
  - Works alongside Discord notifications
- **Enhanced Metrics**: Symptom and root cause tracking
  - Metrics now include problem patterns
  - Better trending analysis
  - Identifies recurring issues
- **Metrics Dashboard**: New `metrics-dashboard.sh` script
  - Visualizes recovery statistics
  - Success rate, average recovery time
  - Top symptoms and root causes
  - 7-day trend analysis

### Changed
- Emergency recovery script refactored to v2.0 (`emergency-recovery-v2.sh`)
- Enhanced Claude instructions for structured reporting
- Improved log rotation (includes reasoning logs)
- Updated `.env.example` with Telegram configuration

### Fixed
- None (initial v2.0 release)

---

## [1.3.4] - 2026-02-06

### Fixed
- SKILL.md version number sync

## [1.3.0] - 2026-02-06 23:20

### Added
- One-Click Installer (`install.sh`)
  - Single command: `curl -sSL .../install.sh | bash`
  - Automatic dependency check
  - LaunchAgent installation
  - Environment setup

### Changed
- README restructured: one-click install prominent, manual install in collapsible

## [1.2.2] - 2026-02-06 22:55

### Added
- Marketing bundle complete (5 platforms: Hacker News, Reddit, Twitter, Discord, Dev.to)
- Demo GIF for README

## [1.2.1] - 2026-02-06 22:05

### Fixed
- Security improvements:
  - Added cleanup trap to prevent resource leaks
  - Lock file permissions (chmod 700)
  - Session log permissions (chmod 600)
- Linux setup documentation (LINUX_SETUP.md)

## [1.2.0] - 2026-02-06 21:00

### Added
- Enhanced documentation (55KB)
- GitHub Actions (ShellCheck)

## [1.1.0] - 2026-02-06 20:00

### Changed
- Documentation improvements
- Code cleanup

## [1.0.0] - 2026-02-06 21:30

### Added
- Initial public release
- 4-tier self-healing architecture:
  - Level 1: Watchdog (180s process monitoring)
  - Level 2: Health Check (300s HTTP verification + 3 retries)
  - Level 3: Claude Emergency Recovery (30min AI-powered diagnosis)
  - Level 4: Discord Notification (human escalation)
- macOS LaunchAgent integration
- Production-tested (verified recovery Feb 5, 2026)
- World's first Claude Code as emergency doctor

[3.4.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v2.1.0...v3.1.0
[2.1.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v2.0.2...v2.1.0
[2.0.2]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.3.4...v2.0.0
[1.3.4]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.3.0...v1.3.4
[1.3.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Ramsbaby/openclaw-self-healing/releases/tag/v1.0.0
