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
  changeOrigin: true, // rewrite Host header to 127.0.0.1 so OpenClaw sees local
});

proxy.on("error", (err, _req, res) => {
  console.error(`[proxy] error: ${err.message}`);
  if (res && typeof res.writeHead === "function") {
    res.writeHead(502, { "Content-Type": "text/plain" });
    res.end("Gateway not ready yet. Try again in a few seconds.");
  }
});

// Strip proxy headers so OpenClaw sees connections as local
function stripProxyHeaders(req) {
  delete req.headers["x-forwarded-for"];
  delete req.headers["x-forwarded-proto"];
  delete req.headers["x-forwarded-host"];
  delete req.headers["x-real-ip"];
  // Rewrite origin to match what OpenClaw expects (loopback)
  // so controlUi origin check passes through the proxy
  if (req.headers["origin"]) {
    req.headers["origin"] = `http://127.0.0.1:${GATEWAY_PORT}`;
  }
}

const server = http.createServer((req, res) => {
  // Health check endpoint
  if (req.url === "/healthz") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
    return;
  }
  stripProxyHeaders(req);
  proxy.web(req, res);
});

server.on("upgrade", (req, socket, head) => {
  stripProxyHeaders(req);
  proxy.ws(req, socket, head);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`[proxy] Listening on port ${PORT}, forwarding to ${GATEWAY_TARGET}`);
});
