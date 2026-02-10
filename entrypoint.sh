#!/bin/bash
set -e

# Fix volume permissions (Railway mounts as root)
chown -R openclaw:openclaw /data 2>/dev/null || true

STATE_DIR="/data/.openclaw"
WORKSPACE_DIR="/data/workspace"
CONFIG_FILE="$STATE_DIR/openclaw.json"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"

# Copy default workspace files if empty
if [ -z "$(ls -A "$WORKSPACE_DIR" 2>/dev/null)" ]; then
  echo "[fastclaw] Copying default workspace files..."
  cp -r /home/openclaw/.openclaw/default-workspace/* "$WORKSPACE_DIR/" 2>/dev/null || true
fi

# Validate tier
if [ -z "$FASTCLAW_TIER" ]; then
  echo "[fastclaw] ERROR: FASTCLAW_TIER is required (basic|pro|premium)"
  exit 1
fi

echo "[fastclaw] Building config for tier: $FASTCLAW_TIER"

# Determine default model per tier
case "$FASTCLAW_TIER" in
  basic)
    DEFAULT_MODEL="${FASTCLAW_MODEL:-moonshot/kimi-k2-0905-preview}"
    ;;
  pro)
    DEFAULT_MODEL="${FASTCLAW_MODEL:-moonshot/kimi-k2-0905-preview}"
    ;;
  premium)
    DEFAULT_MODEL="${FASTCLAW_MODEL:-moonshot/kimi-k2-0905-preview}"
    ;;
  *)
    echo "[fastclaw] ERROR: Unknown tier '$FASTCLAW_TIER'. Use basic|pro|premium"
    exit 1
    ;;
esac

# Generate a gateway token if not provided
GATEWAY_TOKEN="${FASTCLAW_GATEWAY_TOKEN:-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)}"
echo "[fastclaw] Gateway token: $GATEWAY_TOKEN"

# Build providers block
PROVIDERS='{}'

if [ -n "$ANTHROPIC_API_KEY" ]; then
  PROVIDERS=$(echo "$PROVIDERS" | jq --arg key "$ANTHROPIC_API_KEY" '. + {
    "anthropic": { "apiKey": $key }
  }')
fi

if [ -n "$OPENAI_API_KEY" ]; then
  PROVIDERS=$(echo "$PROVIDERS" | jq --arg key "$OPENAI_API_KEY" '. + {
    "openai": { "apiKey": $key }
  }')
fi

if [ -n "$MOONSHOT_API_KEY" ]; then
  PROVIDERS=$(echo "$PROVIDERS" | jq --arg key "$MOONSHOT_API_KEY" '. + {
    "moonshot": {
      "baseUrl": "https://api.moonshot.ai/v1",
      "api": "openai-completions",
      "apiKey": $key,
      "models": [
        {
          "id": "kimi-k2-0905-preview",
          "name": "Kimi K2",
          "reasoning": false,
          "input": ["text"],
          "cost": { "input": 0, "output": 0 }
        }
      ]
    }
  }')
fi

# Bot name/avatar
BOT_NAME="${FASTCLAW_BOT_NAME:-Assistant}"
BOT_AVATAR="${FASTCLAW_BOT_AVATAR:-🤖}"

# Always regenerate config (gateway binds to loopback, proxy handles public traffic)
cat > "$CONFIG_FILE" << JSONEOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": ${INTERNAL_GATEWAY_PORT:-18789},
    "auth": {
      "mode": "token",
      "token": "$GATEWAY_TOKEN"
    }
  },
  "ui": {
    "assistant": {
      "name": "$BOT_NAME",
      "avatar": "$BOT_AVATAR"
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
      "workspace": "$WORKSPACE_DIR"
    }
  },
  "channels": {}
}
JSONEOF

chown -R openclaw:openclaw "$STATE_DIR" "$WORKSPACE_DIR"

echo "[fastclaw] Config written to $CONFIG_FILE"
echo "[fastclaw] Default model: $DEFAULT_MODEL"
echo "[fastclaw] Tier: $FASTCLAW_TIER"
echo "[fastclaw] Gateway binds to loopback:${INTERNAL_GATEWAY_PORT:-18789}"
echo "[fastclaw] Proxy on public port: ${PORT:-8080}"

# Export for OpenClaw
export HOME="/home/openclaw"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_WORKSPACE_DIR="$WORKSPACE_DIR"
export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"

# Start gateway on loopback (as openclaw user)
echo "[fastclaw] Starting OpenClaw gateway..."
gosu openclaw node /usr/local/lib/node_modules/openclaw/dist/entry.js gateway run \
  --bind loopback \
  --port "${INTERNAL_GATEWAY_PORT:-18789}" \
  --auth token \
  --token "$GATEWAY_TOKEN" &
GATEWAY_PID=$!

# Wait for gateway to be ready
echo "[fastclaw] Waiting for gateway to be ready..."
for i in $(seq 1 60); do
  if curl -sf http://127.0.0.1:${INTERNAL_GATEWAY_PORT:-18789}/ > /dev/null 2>&1; then
    echo "[fastclaw] Gateway is ready!"
    break
  fi
  sleep 1
done

# Start reverse proxy on public port (as openclaw user)
echo "[fastclaw] Starting reverse proxy on port ${PORT:-8080}..."
gosu openclaw node /app/server.js &
PROXY_PID=$!

# Wait for either to exit
wait -n $GATEWAY_PID $PROXY_PID
EXIT_CODE=$?
echo "[fastclaw] Process exited with code $EXIT_CODE"

# Kill the other process
kill $GATEWAY_PID $PROXY_PID 2>/dev/null || true
exit $EXIT_CODE
