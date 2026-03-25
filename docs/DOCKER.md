# Docker Compose

Run the OpenClaw Gateway and its self-healing watchdog together with a single command.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/) installed
- `~/.openclaw/.env` already configured (run `install.sh` first, or create manually)

## Quick Start

```bash
# 1. Copy the example env file if you haven't already
cp .env.example ~/.openclaw/.env
# Edit ~/.openclaw/.env and fill in your values

# 2. Start both services
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/... docker compose up -d

# 3. Check status
docker compose ps
docker compose logs -f
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DISCORD_WEBHOOK_URL` | *(empty)* | Discord webhook for recovery alerts |
| `NOTIFICATION_CHANNEL` | `discord` | Notification channel: `discord`, `slack`, or `telegram` |
| `SLACK_WEBHOOK_URL` | *(empty)* | Slack webhook (when `NOTIFICATION_CHANNEL=slack`) |
| `TELEGRAM_BOT_TOKEN` | *(empty)* | Telegram bot token (when `NOTIFICATION_CHANNEL=telegram`) |
| `TELEGRAM_CHAT_ID` | *(empty)* | Telegram chat ID |

You can set these inline or add them to a `.env` file in the repo root (Docker Compose reads it automatically):

```bash
# .env (repo root — git-ignored)
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/xxx/yyy
NOTIFICATION_CHANNEL=discord
```

## Services

### `openclaw-gateway`

Runs the OpenClaw Gateway on port `18789`. Performs a health check every 30 seconds against `http://localhost:18789/`.

### `self-healing-watchdog`

Starts only after the gateway reports healthy. Runs `scripts/gateway-watchdog.sh` on a loop, using the unified `scripts/lib/notify.sh` library to send alerts.

## Common Commands

```bash
# Start in foreground (see logs live)
docker compose up

# Start in background
docker compose up -d

# Stop everything
docker compose down

# Restart the watchdog only
docker compose restart self-healing-watchdog

# View watchdog logs
docker compose logs -f self-healing-watchdog

# Shell into the watchdog container for debugging
docker compose exec self-healing-watchdog bash
```

## Adapting for Other Services

To monitor a different service, edit `docker-compose.yml`:

1. Replace the `openclaw-gateway` service with your own service definition.
2. Update the `healthcheck` URL to match your service's health endpoint.
3. The `self-healing-watchdog` service will wait until your service is healthy before starting.

See [docs/configuration.md](configuration.md) for full watchdog configuration options.
