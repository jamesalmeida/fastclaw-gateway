FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/jamesalmeida/fastclaw-gateway"
LABEL org.opencontainers.image.description="Actually Useful AI — managed OpenClaw gateway"

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates jq gosu ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install CLI tools required by bundled OpenClaw skills
RUN set -eux; \
    GH_VERSION="2.86.0"; \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.deb" -o /tmp/gh.deb; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/gh.deb; \
    rm -f /tmp/gh.deb; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    GOG_VERSION="0.9.0"; \
    GOG_URL="$(curl -fsSL "https://api.github.com/repos/steipete/gogcli/releases/tags/v${GOG_VERSION}" | jq -r '.assets[] | select(.name | test("linux.*(amd64|x86_64).*\\.tar\\.gz$"; "i")) | .browser_download_url' | head -n1)"; \
    test -n "${GOG_URL}"; \
    mkdir -p /tmp/gog-extract; \
    curl -fsSL "${GOG_URL}" -o /tmp/gog.tar.gz; \
    tar -xzf /tmp/gog.tar.gz -C /tmp/gog-extract; \
    GOG_BIN="$(find /tmp/gog-extract -type f -name gog | head -n1)"; \
    test -n "${GOG_BIN}"; \
    install -m 0755 "${GOG_BIN}" /usr/local/bin/gog; \
    rm -rf /tmp/gog-extract /tmp/gog.tar.gz

RUN set -eux; \
    HIMALAYA_URL="$(curl -fsSL "https://api.github.com/repos/pimalaya/himalaya/releases/latest" | jq -r '.assets[] | select(.name == "himalaya.x86_64-linux.tgz") | .browser_download_url')"; \
    test -n "${HIMALAYA_URL}"; \
    mkdir -p /tmp/himalaya-extract; \
    curl -fsSL "${HIMALAYA_URL}" -o /tmp/himalaya.tgz; \
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
