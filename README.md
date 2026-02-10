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

```bash
cp .env.example .env
# Edit .env with your settings
docker compose up -d
```

## Environment variables

See `.env.example` for all options.

### Required
- `FASTCLAW_TIER` — `basic`, `pro`, or `premium`

### Optional
- `FASTCLAW_BOT_NAME` — Bot display name (default: "Assistant")
- `FASTCLAW_BOT_AVATAR` — Bot emoji avatar (default: 🤖)
- `FASTCLAW_MODEL` — Override the default model for the tier
- API keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `MOONSHOT_API_KEY`
- Channel config: `WHATSAPP_*`, `TELEGRAM_*`

## Build

```bash
docker build -t fastclaw-gateway .
```

## CI/CD

GitHub Actions builds and pushes to `ghcr.io/jamesalmeida/fastclaw-gateway` on every push to `main`.
