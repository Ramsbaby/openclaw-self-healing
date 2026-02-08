# Linux Setup Guide (systemd)

> ⚠️ **Work in Progress** - This is a community contribution template. Full Linux support is on the roadmap.

## Overview

This guide provides systemd equivalents for the macOS LaunchAgent-based self-healing system.

## Prerequisites

- Linux (Ubuntu 20.04+, Debian 11+, or similar)
- systemd
- OpenClaw Gateway installed
- tmux (`apt install tmux`)
- Claude CLI (`npm install -g @anthropic-ai/claude-code`)

## Level 1: Watchdog (systemd)

Create `/etc/systemd/system/openclaw-gateway.service`:

```ini
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=YOUR_USER
WorkingDirectory=/home/YOUR_USER
ExecStart=/usr/local/bin/openclaw gateway start
Restart=always
RestartSec=180

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable openclaw-gateway
sudo systemctl start openclaw-gateway
```

## Level 2: Health Check (systemd timer)

Create `/etc/systemd/system/openclaw-healthcheck.service`:

```ini
[Unit]
Description=OpenClaw Health Check

[Service]
Type=oneshot
User=YOUR_USER
ExecStart=/home/YOUR_USER/openclaw/scripts/gateway-healthcheck.sh
```

Create `/etc/systemd/system/openclaw-healthcheck.timer`:

```ini
[Unit]
Description=Run OpenClaw Health Check every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

Enable:
```bash
sudo systemctl enable openclaw-healthcheck.timer
sudo systemctl start openclaw-healthcheck.timer
```

## Level 3 & 4

Scripts work the same on Linux. Update paths in `.env`:

```bash
OPENCLAW_DIR=/home/YOUR_USER/openclaw
LOG_DIR=/home/YOUR_USER/openclaw/memory
```

## Script Modifications

Replace macOS-specific commands:

| macOS | Linux |
|-------|-------|
| `launchctl` | `systemctl` |
| `~/Library/LaunchAgents/` | `/etc/systemd/system/` |
| `open` | `xdg-open` |

## Contributing

Help us improve Linux support! See [CONTRIBUTING.md](/CONTRIBUTING.md).
