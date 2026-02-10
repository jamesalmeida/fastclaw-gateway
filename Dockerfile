FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/jamesalmeida/fastclaw-gateway"
LABEL org.opencontainers.image.description="Actually Useful AI — managed OpenClaw gateway"

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates jq gosu \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Create app directory for the proxy server
WORKDIR /app
COPY proxy/package.json proxy/pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile --prod

COPY proxy/server.js ./server.js

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create user and directories
RUN useradd -m -s /bin/bash openclaw \
    && mkdir -p /data && chown openclaw:openclaw /data \
    && mkdir -p /home/openclaw/.openclaw/workspace \
    && chown -R openclaw:openclaw /home/openclaw/.openclaw

# Copy default workspace files
COPY workspace/ /home/openclaw/.openclaw/default-workspace/
RUN chown -R openclaw:openclaw /home/openclaw/.openclaw/default-workspace

WORKDIR /home/openclaw/.openclaw/workspace

ENV PORT=8080
ENV INTERNAL_GATEWAY_PORT=18789
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD curl -f http://localhost:8080/healthz || exit 1

ENTRYPOINT ["entrypoint.sh"]
