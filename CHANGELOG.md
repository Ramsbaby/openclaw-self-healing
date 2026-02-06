# Changelog

## [1.3.1] - 2026-02-06

### Fixed
- **Dead code removed**: Unused `log_incident()` function removed from emergency-recovery.sh
- **Claude completion polling**: No longer waits full 30 minutes; detects completion via output polling (saves up to 25 minutes)
- **Secure temp files**: Uses `mktemp` instead of predictable `/tmp` paths
- **Session log permissions**: `chmod 600` on Claude session logs

### Security
- Temp file race condition fixed
- Log file permissions hardened

## [1.3.0] - 2026-02-06

### Added
- **One-Click Installer**: `curl -sSL .../install.sh | bash` for instant setup
- Custom workspace support via `--workspace` flag
- Automatic prerequisite checking (tmux, Claude CLI, OpenClaw)
- Interactive setup with colored output

### Improved
- README restructured with one-click install prominently featured
- Manual installation moved to collapsible section
- Installation time reduced from 5 minutes to ~30 seconds

## [1.2.1] - 2026-02-06

### Security
- Added cleanup trap to prevent orphan tmux sessions
- Changed log permissions to `chmod 700` (was 600)
- Added `LINUX_SETUP.md` for systemd users

## [1.1.0] - 2026-02-06

### Added
- **Incident Documentation**: Auto-generates incident reports with diagnosis, resolution, and prevention steps (ContextVault feedback)
- **Reasoning Trace**: Claude's diagnostic process is now captured in incident logs (FiverrClawOfficial feedback)

### Improved
- Better error messages in health check script
- Added memory/incidents/ directory for historical tracking

## [1.0.0] - 2026-02-06

### Initial Release
- 4-tier autonomous self-healing architecture
- Level 1: Watchdog (180s process monitoring)
- Level 2: Health Check (300s HTTP + 3 retries)
- Level 3: Claude Recovery (30min AI diagnosis)
- Level 4: Discord Alert (human escalation)

## [1.2.2] - 2026-02-06

### Added
- Demo GIF showing 4-tier recovery in action
- Visual documentation in README
- `assets/` directory for media files
