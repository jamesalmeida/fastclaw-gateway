FROM node:22-slim

LABEL org.opencontainers.image.source="https://github.com/jamesalmeida/fastclaw-gateway"
LABEL org.opencontainers.image.description="Actually Useful AI — managed OpenClaw gateway"

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Pre-install common skills
RUN npm install -g \
    @openclaw/skill-weather \
    @openclaw/skill-summarize \
    2>/dev/null || true

# Create workspace & config directories
RUN mkdir -p /home/node/.openclaw/workspace \
    && chown -R node:node /home/node/.openclaw

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy default workspace files
COPY workspace/ /home/node/.openclaw/default-workspace/

USER node
WORKDIR /home/node/.openclaw/workspace

EXPOSE 18789

ENTRYPOINT ["entrypoint.sh"]
