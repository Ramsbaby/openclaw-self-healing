# Changelog

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
