/**
 * Minimal reverse proxy for Railway-hosted OpenClaw.
 * 
 * Gateway binds to loopback → all connections appear local → no device pairing.
 * This proxy sits on the public PORT and forwards everything (HTTP + WebSocket).
 */
import http from "node:http";
import httpProxy from "http-proxy";

const PORT = parseInt(process.env.PORT ?? "8080", 10);
const GATEWAY_PORT = parseInt(process.env.INTERNAL_GATEWAY_PORT ?? "18789", 10);
const GATEWAY_TARGET = `http://127.0.0.1:${GATEWAY_PORT}`;

const proxy = httpProxy.createProxyServer({
  target: GATEWAY_TARGET,
  ws: true,
  changeOrigin: false, // keep origin for OpenClaw
});

proxy.on("error", (err, _req, res) => {
  console.error(`[proxy] error: ${err.message}`);
  if (res && typeof res.writeHead === "function") {
    res.writeHead(502, { "Content-Type": "text/plain" });
    res.end("Gateway not ready yet. Try again in a few seconds.");
  }
});

const server = http.createServer((req, res) => {
  // Health check endpoint
  if (req.url === "/healthz") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
    return;
  }
  proxy.web(req, res);
});

server.on("upgrade", (req, socket, head) => {
  proxy.ws(req, socket, head);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`[proxy] Listening on port ${PORT}, forwarding to ${GATEWAY_TARGET}`);
});
