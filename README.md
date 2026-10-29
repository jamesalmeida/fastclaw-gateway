# fastclaw-gateway

Docker image for **Actually Useful AI** managed OpenClaw instances.

## How it works

Each customer gets their own container running an OpenClaw gateway, configured via environment variables. The entrypoint script generates `openclaw.json` from env vars at startup.

## Tiers

| Tier | Default Model | What's included |
|------|--------------|-----------------|
| **Basic** ($9/mo) | Claude Sonnet (BYOK) | User brings their own API key |
| **Pro** ($29/mo) | Kimi K2 | API key included, 1-day free trial |
| **Premium** ($59/mo) | Claude Sonnet | Premium model + K2 fallback |

## Quick start

`docker-compose.yml` reads its values from the shell or from a `.env` file next to it. Create `.env` and fill in at least `FASTCLAW_TIER`:

```bash
printf 'FASTCLAW_TIER=pro\n' > .env
docker compose up -d
```

The gateway binds to loopback on port 18789; the proxy handles public traffic.

## Environment variables

### Required
- `FASTCLAW_TIER` — `basic`, `pro`, or `premium` (validated by the entrypoint)

### Optional
- `FASTCLAW_BOT_NAME` — Bot display name (default: "Assistant")
- `FASTCLAW_BOT_AVATAR` — Bot emoji avatar (default: 🤖)
- `FASTCLAW_MODEL` — Override the model; otherwise the entrypoint picks one from the API keys present
- `FASTCLAW_GATEWAY_TOKEN` — Gateway auth token (a random token is generated if unset)
- Model keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `MOONSHOT_API_KEY`, plus `GOOGLE_API_KEY` and `XAI_API_KEY` (OpenClaw auto-discovers them)
- Telegram: `FASTCLAW_TELEGRAM_BOT_TOKEN`, `FASTCLAW_TELEGRAM_BOT_USERNAME`, `TELEGRAM_ALLOW_FROM`
- WhatsApp: `WHATSAPP_PHONE_ID`, `WHATSAPP_TOKEN`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_WEBHOOK_SECRET`, `WHATSAPP_ALLOW_FROM`

## Build

The image builds on `node:24.22.1-bookworm`.

```bash
docker build -t fastclaw-gateway .
```

## CI/CD

GitHub Actions builds and pushes to `ghcr.io/jamesalmeida/fastclaw-gateway` on every push to `main`.
