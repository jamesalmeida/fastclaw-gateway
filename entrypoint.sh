#!/bin/bash
set -e

# Fix volume permissions (Railway mounts as root)
if [ "$(id -u)" = "0" ]; then
  chown -R node:node /home/node/.openclaw 2>/dev/null || true
  exec su -s /bin/bash node -- "$0" "$@"
fi

CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE="$CONFIG_DIR/workspace"

# Copy default workspace files if workspace is empty
if [ -d "$CONFIG_DIR/default-workspace" ] && [ -z "$(ls -A "$WORKSPACE" 2>/dev/null)" ]; then
  cp -r "$CONFIG_DIR/default-workspace/." "$WORKSPACE/"
  echo "[fastclaw] Initialized workspace with default files"
fi

# ─── Required env vars ───
if [ -z "$FASTCLAW_TIER" ]; then
  echo "[fastclaw] ERROR: FASTCLAW_TIER is required (basic|pro|premium)"
  exit 1
fi

# ─── Build config from env vars ───
echo "[fastclaw] Building config for tier: $FASTCLAW_TIER"

# Determine default model based on tier
case "$FASTCLAW_TIER" in
  basic)
    # Basic tier: user brings their own key, we set a sensible default
    DEFAULT_MODEL="${FASTCLAW_MODEL:-anthropic/claude-sonnet-4-20250514}"
    ;;
  pro)
    # Pro tier: Kimi K2 included (free model)
    DEFAULT_MODEL="${FASTCLAW_MODEL:-moonshot/kimi-k2-0905-preview}"
    ;;
  premium)
    # Premium tier: Claude with K2 fallback
    DEFAULT_MODEL="${FASTCLAW_MODEL:-anthropic/claude-sonnet-4-20250514}"
    ;;
  *)
    echo "[fastclaw] ERROR: Unknown tier '$FASTCLAW_TIER'. Use basic|pro|premium"
    exit 1
    ;;
esac

# ─── Build providers block ───
PROVIDERS="{}"

# Anthropic (for basic BYOK or premium)
if [ -n "$ANTHROPIC_API_KEY" ]; then
  PROVIDERS=$(echo "$PROVIDERS" | jq --arg key "$ANTHROPIC_API_KEY" '. + {
    "anthropic": {
      "apiKey": $key
    }
  }')
fi

# OpenAI (optional BYOK)
if [ -n "$OPENAI_API_KEY" ]; then
  PROVIDERS=$(echo "$PROVIDERS" | jq --arg key "$OPENAI_API_KEY" '. + {
    "openai": {
      "apiKey": $key
    }
  }')
fi

# Moonshot / Kimi K2 (pro tier gets this by default)
if [ -n "$MOONSHOT_API_KEY" ]; then
  PROVIDERS=$(echo "$PROVIDERS" | jq --arg key "$MOONSHOT_API_KEY" '. + {
    "moonshot": {
      "baseUrl": "https://api.moonshot.ai/v1",
      "api": "openai-completions",
      "apiKey": $key,
      "models": [{
        "id": "kimi-k2-0905-preview",
        "name": "Kimi K2",
        "reasoning": false,
        "input": ["text"],
        "cost": { "input": 0, "output": 0 }
      }]
    }
  }')
fi

# ─── Build channel config ───
CHANNELS="{}"

# WhatsApp
if [ -n "$WHATSAPP_PHONE_ID" ]; then
  CHANNELS=$(echo "$CHANNELS" | jq \
    --arg phoneId "$WHATSAPP_PHONE_ID" \
    --arg token "$WHATSAPP_TOKEN" \
    --arg verifyToken "$WHATSAPP_VERIFY_TOKEN" \
    --arg webhookSecret "$WHATSAPP_WEBHOOK_SECRET" \
    --arg allowFrom "${WHATSAPP_ALLOW_FROM:-}" \
    '. + {
      "whatsapp": {
        "phoneNumberId": $phoneId,
        "accessToken": $token,
        "verifyToken": $verifyToken,
        "webhookSecret": $webhookSecret,
        "allowFrom": (if $allowFrom != "" then ($allowFrom | split(",")) else [] end)
      }
    }')
fi

# Telegram
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  CHANNELS=$(echo "$CHANNELS" | jq \
    --arg token "$TELEGRAM_BOT_TOKEN" \
    --arg allowFrom "${TELEGRAM_ALLOW_FROM:-}" \
    '. + {
      "telegram": {
        "botToken": $token,
        "allowFrom": (if $allowFrom != "" then ($allowFrom | split(",") | map(tonumber)) else [] end)
      }
    }')
fi

# ─── Build the full config ───
# If config already exists (from volume), update password and reuse
if [ -f "$CONFIG_FILE" ]; then
  echo "[fastclaw] Existing config found, updating auth and reusing"
  GATEWAY_TOKEN="${FASTCLAW_GATEWAY_TOKEN:-$(cat "$CONFIG_FILE" | jq -r '.gateway.auth.password // .gateway.auth.token // empty')}"
  # Update to password auth mode
  UPDATED=$(cat "$CONFIG_FILE" | jq --arg pw "$GATEWAY_TOKEN" '.gateway.auth = { "mode": "password", "password": $pw }')
  echo "$UPDATED" > "$CONFIG_FILE"
  echo "[fastclaw] Gateway password: $GATEWAY_TOKEN"
  echo "[fastclaw] Starting OpenClaw gateway..."
  exec openclaw gateway --force
fi

# Generate a gateway token if not provided
GATEWAY_TOKEN="${FASTCLAW_GATEWAY_TOKEN:-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)}"
echo "[fastclaw] Gateway token: $GATEWAY_TOKEN"

cat > "$CONFIG_FILE" << JSONEOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "password",
      "password": "$GATEWAY_TOKEN"
    }
  },
  "ui": {
    "assistant": {
      "name": "${FASTCLAW_BOT_NAME:-Assistant}",
      "avatar": "${FASTCLAW_BOT_AVATAR:-🤖}"
    }
  },
  "models": {
    "providers": $(echo "$PROVIDERS" | jq -c .)
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "$DEFAULT_MODEL"
      },
      "workspace": "$WORKSPACE"
    }
  },
  "channels": $(echo "$CHANNELS" | jq -c .)
}
JSONEOF

echo "[fastclaw] Config written to $CONFIG_FILE"
echo "[fastclaw] Default model: $DEFAULT_MODEL"
echo "[fastclaw] Starting OpenClaw gateway..."

# Start the gateway
exec openclaw gateway --force
