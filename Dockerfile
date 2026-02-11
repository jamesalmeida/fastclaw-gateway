FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/jamesalmeida/fastclaw-gateway"
LABEL org.opencontainers.image.description="Actually Useful AI — managed OpenClaw gateway"

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates jq gosu ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install CLI tools required by bundled OpenClaw skills
# gh CLI (arch-aware)
RUN set -eux; \
    GH_VERSION="2.86.0"; \
    ARCH="$(dpkg --print-architecture)"; \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" -o /tmp/gh.deb; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/gh.deb; \
    rm -f /tmp/gh.deb; \
    rm -rf /var/lib/apt/lists/*

# gog - Google Workspace CLI (arch-aware)
RUN set -eux; \
    GOG_VERSION="0.9.0"; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in x86_64) GOG_ARCH="amd64" ;; aarch64) GOG_ARCH="arm64" ;; *) GOG_ARCH="$ARCH" ;; esac; \
    curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${GOG_ARCH}.tar.gz" -o /tmp/gog.tar.gz; \
    mkdir -p /tmp/gog-extract; \
    tar -xzf /tmp/gog.tar.gz -C /tmp/gog-extract; \
    GOG_BIN="$(find /tmp/gog-extract -type f -name gog | head -n1)"; \
    test -n "${GOG_BIN}"; \
    install -m 0755 "${GOG_BIN}" /usr/local/bin/gog; \
    rm -rf /tmp/gog-extract /tmp/gog.tar.gz

# himalaya - email CLI (arch-aware)
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in aarch64) HIM_ARCH="aarch64" ;; *) HIM_ARCH="x86_64" ;; esac; \
    curl -fsSL "https://github.com/pimalaya/himalaya/releases/latest/download/himalaya.${HIM_ARCH}-linux.tgz" -o /tmp/himalaya.tgz; \
    mkdir -p /tmp/himalaya-extract; \
    tar -xzf /tmp/himalaya.tgz -C /tmp/himalaya-extract; \
    HIMALAYA_BIN="$(find /tmp/himalaya-extract -type f -name himalaya | head -n1)"; \
    test -n "${HIMALAYA_BIN}"; \
    install -m 0755 "${HIMALAYA_BIN}" /usr/local/bin/himalaya; \
    rm -rf /tmp/himalaya-extract /tmp/himalaya.tgz

# Install OpenClaw globally
RUN npm install -g openclaw@latest @google/gemini-cli @steipete/summarize

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
