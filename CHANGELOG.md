# Changelog

All notable changes to OpenClaw Self-Healing System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[2.0.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.3.4...v2.0.0
[1.3.4]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.3.0...v1.3.4
[1.3.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Ramsbaby/openclaw-self-healing/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Ramsbaby/openclaw-self-healing/releases/tag/v1.0.0
