#!/bin/bash
set -e

# Running as root — single-tenant sandboxed container

STATE_DIR="/data/.openclaw"
WORKSPACE_DIR="/data/workspace"
CONFIG_FILE="$STATE_DIR/openclaw.json"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"

# Copy default workspace files if empty
if [ -z "$(ls -A "$WORKSPACE_DIR" 2>/dev/null)" ]; then
  echo "[fastclaw] Copying default workspace files..."
  cp -r /root/.openclaw/default-workspace/* "$WORKSPACE_DIR/" 2>/dev/null || true
else
  # Always update AGENTS.md and SOUL.md from image (managed files)
  for f in AGENTS.md SOUL.md; do
    if [ -f "/root/.openclaw/default-workspace/$f" ]; then
      cp "/root/.openclaw/default-workspace/$f" "$WORKSPACE_DIR/$f"
    fi
  done
fi

# Validate tier
if [ -z "$FASTCLAW_TIER" ]; then
  echo "[fastclaw] ERROR: FASTCLAW_TIER is required (basic|pro|premium)"
  exit 1
fi

echo "[fastclaw] Building config for tier: $FASTCLAW_TIER"

# Determine default model per tier
case "$FASTCLAW_TIER" in
  basic|pro|premium) ;; # valid
  *)
    echo "[fastclaw] ERROR: Unknown tier '$FASTCLAW_TIER'. Use basic|pro|premium"
    exit 1
    ;;
esac

# Auto-detect default model from available API keys (user can override with FASTCLAW_MODEL)
# Priority: cheapest to most expensive
if [ -n "$FASTCLAW_MODEL" ]; then
  DEFAULT_MODEL="$FASTCLAW_MODEL"
elif [ -n "$MOONSHOT_API_KEY" ]; then
  DEFAULT_MODEL="moonshot/kimi-k2-0905-preview"  # free
elif [ -n "$GOOGLE_API_KEY" ]; then
  DEFAULT_MODEL="google/gemini-2.5-flash"         # cheapest paid
elif [ -n "$XAI_API_KEY" ]; then
  DEFAULT_MODEL="xai/grok-4-1-fast-reasoning"  # cheapest xAI model, reasoning enabled
elif [ -n "$OPENAI_API_KEY" ]; then
  DEFAULT_MODEL="openai/gpt-4o"
elif [ -n "$ANTHROPIC_API_KEY" ]; then
  DEFAULT_MODEL="anthropic/claude-sonnet-4-20250514"  # most expensive
else
  DEFAULT_MODEL="moonshot/kimi-k2-0905-preview"
  echo "[fastclaw] WARNING: No API keys found — default model may not work"
fi

# Generate a gateway token if not provided
GATEWAY_TOKEN="${FASTCLAW_GATEWAY_TOKEN:-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)}"
echo "[fastclaw] Gateway token: $GATEWAY_TOKEN"

# Build providers block
PROVIDERS='{}'

# Anthropic and OpenAI are built-in providers in OpenClaw — they auto-discover
# from env vars. Don't add them to the custom providers block or OpenClaw will
# require baseUrl/models fields. Just export the env vars and they'll work.
# ANTHROPIC_API_KEY and OPENAI_API_KEY are already set in the environment.

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

# Google and xAI are now native providers in OpenClaw 2026.2.6+ — auto-discovered
# from GOOGLE_API_KEY and XAI_API_KEY env vars. No custom config needed.

# Shared Brave Search API key (bundled for all tiers)
BRAVE_KEY="${BRAVE_API_KEY:-BSAgAiUN2lAkYyoPpeX7lkUlzMidsaz}"

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
    "controlUi": {
      "allowedOrigins": ["https://${RAILWAY_PUBLIC_DOMAIN:-localhost}"]
    },
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
  "update": {
    "channel": "stable",
    "checkOnStart": false
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
  "tools": {
    "web": {
      "search": {
        "apiKey": "$BRAVE_KEY"
      }
    }
  },
  "channels": {}
}

JSONEOF

# Inject Telegram channel if token is provided
if [ -n "$FASTCLAW_TELEGRAM_BOT_TOKEN" ]; then
  echo "[fastclaw] Configuring Telegram channel..."
  TELEGRAM_ALLOW="${TELEGRAM_ALLOW_FROM:-}"
  TMP_CONFIG=$(mktemp)
  jq --arg token "$FASTCLAW_TELEGRAM_BOT_TOKEN" \
     --arg allow "$TELEGRAM_ALLOW" \
     '.channels.telegram = {
       "enabled": true,
       "botToken": $token,
       "dmPolicy": "open"
     } | if $allow != "" then .channels.telegram.allowFrom = ($allow | split(",")) else . end' \
     "$CONFIG_FILE" > "$TMP_CONFIG" && mv "$TMP_CONFIG" "$CONFIG_FILE"
  echo "[fastclaw] Telegram bot configured${FASTCLAW_TELEGRAM_BOT_USERNAME:+ (@$FASTCLAW_TELEGRAM_BOT_USERNAME)}"
fi

echo "[fastclaw] Config written to $CONFIG_FILE"
echo "[fastclaw] Default model: $DEFAULT_MODEL"
echo "[fastclaw] Tier: $FASTCLAW_TIER"
echo "[fastclaw] Gateway binds to loopback:${INTERNAL_GATEWAY_PORT:-18789}"
echo "[fastclaw] Proxy on public port: ${PORT:-8080}"

# ── gog (Google Workspace) setup ──
# If Google OAuth tokens are provided via env vars, configure gog automatically
if [ -n "$GOG_GOOGLE_REFRESH_TOKEN" ] && [ -n "$GOG_GOOGLE_EMAIL" ]; then
  echo "[fastclaw] Configuring gog for $GOG_GOOGLE_EMAIL..."

  # Set keyring password for file-based keyring (no system keychain in container)
  export GOG_KEYRING_PASSWORD="${GOG_KEYRING_PASSWORD:-fastclaw-keyring-secret}"

  # Decode and write client_secret.json from base64 env var
  if [ -n "$GOG_CLIENT_SECRET_JSON_B64" ]; then
    echo "$GOG_CLIENT_SECRET_JSON_B64" | base64 -d > /tmp/client_secret.json
    gog auth credentials /tmp/client_secret.json 2>/dev/null || true
    rm -f /tmp/client_secret.json
  fi

  # Set default account
  export GOG_ACCOUNT="$GOG_GOOGLE_EMAIL"

  # Default scopes and services for all accounts
  GOG_SCOPES='["https://mail.google.com/","https://www.googleapis.com/auth/calendar","https://www.googleapis.com/auth/calendar.events","https://www.googleapis.com/auth/calendar.readonly","https://www.googleapis.com/auth/contacts.readonly","https://www.googleapis.com/auth/documents","https://www.googleapis.com/auth/gmail.send","https://www.googleapis.com/auth/gmail.readonly","https://www.googleapis.com/auth/spreadsheets","https://www.googleapis.com/auth/tasks","https://www.googleapis.com/auth/drive"]'
  GOG_SERVICES='["gmail","calendar","drive","contacts","docs","sheets","tasks"]'

  import_single_token() {
    local email="$1"
    local refresh_token="$2"
    cat > /tmp/gog_token.json <<TOKEOF
{
  "email": "$email",
  "services": $GOG_SERVICES,
  "scopes": $GOG_SCOPES,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "refresh_token": "$refresh_token"
}
TOKEOF
    gog auth tokens import /tmp/gog_token.json --no-input 2>&1 || echo "[fastclaw] Warning: gog token import failed for $email"
    rm -f /tmp/gog_token.json
  }

  # Multi-account: GOG_ACCOUNTS_JSON (base64-encoded JSON array)
  if [ -n "${GOG_ACCOUNTS_JSON:-}" ]; then
    echo "[fastclaw] Importing multiple Google accounts..."
    ACCOUNTS_DECODED=$(echo "$GOG_ACCOUNTS_JSON" | base64 -d 2>/dev/null)
    ACCOUNT_COUNT=$(echo "$ACCOUNTS_DECODED" | jq 'length' 2>/dev/null || echo "0")
    
    for i in $(seq 0 $((ACCOUNT_COUNT - 1))); do
      ACC_EMAIL=$(echo "$ACCOUNTS_DECODED" | jq -r ".[$i].email")
      ACC_TOKEN=$(echo "$ACCOUNTS_DECODED" | jq -r ".[$i].refresh_token")
      if [ -n "$ACC_EMAIL" ] && [ "$ACC_EMAIL" != "null" ] && [ -n "$ACC_TOKEN" ] && [ "$ACC_TOKEN" != "null" ]; then
        echo "[fastclaw] Importing account: $ACC_EMAIL"
        import_single_token "$ACC_EMAIL" "$ACC_TOKEN"
        # Set first account as default
        if [ "$i" -eq 0 ]; then
          export GOG_ACCOUNT="$ACC_EMAIL"
        fi
      fi
    done
  else
    # Single account fallback (legacy env vars)
    import_single_token "$GOG_GOOGLE_EMAIL" "$GOG_GOOGLE_REFRESH_TOKEN"
  fi

  echo "[fastclaw] gog configured for $GOG_GOOGLE_EMAIL"
else
  echo "[fastclaw] No Google tokens found — skipping gog setup"
fi

# Export for OpenClaw
export HOME="/root"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_WORKSPACE_DIR="$WORKSPACE_DIR"
export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"

# Start gateway on loopback (running as root)
echo "[fastclaw] Starting OpenClaw gateway..."
node /usr/local/lib/node_modules/openclaw/dist/entry.js gateway run \
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

# Start reverse proxy on public port
echo "[fastclaw] Starting reverse proxy on port ${PORT:-8080}..."
node /app/server.js &
PROXY_PID=$!

# Wait for either to exit
wait -n $GATEWAY_PID $PROXY_PID
EXIT_CODE=$?
echo "[fastclaw] Process exited with code $EXIT_CODE"

# Kill the other process
kill $GATEWAY_PID $PROXY_PID 2>/dev/null || true
exit $EXIT_CODE
