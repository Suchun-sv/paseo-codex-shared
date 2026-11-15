// Minimal second client of the shared app-server (simulates Codex Desktop).
// usage: node wsc.mjs '<json array of [method, params]>'   — waits for turn/completed after turn/start
import { createRequire } from "node:module";
import os from "node:os";
import path from "node:path";
const WebSocket = createRequire(process.env.PASEO_CLI_DIR || "/usr/lib/node_modules/@getpaseo/cli/")("ws");
const CODEX_HOME = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
const SOCKET = process.env.CODEX_CONTROL_SOCKET || path.join(CODEX_HOME, "app-server-control/app-server-control.sock");
const steps = JSON.parse(process.argv[2]);
const ws = new WebSocket(`ws+unix://${SOCKET}:/`);
let id = 100; const waiters = new Map(); let turnDone = null;
const call = (method, params) => new Promise((res) => { const i = ++id; waiters.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
ws.on("message", (m) => {
  const msg = JSON.parse(String(m));
  if (msg.id !== undefined && waiters.has(msg.id)) { waiters.get(msg.id)(msg); waiters.delete(msg.id); return; }
  if (msg.id !== undefined && msg.method) { console.log("  [server request to this client]", msg.method, "id", msg.id); return; }
  if (msg.method === "turn/completed" && turnDone) turnDone(msg);
});
ws.on("open", async () => {
  await call("initialize", { clientInfo: { name: "fake_desktop", title: "fake desktop", version: "0" }, capabilities: { experimentalApi: true } });
  ws.send(JSON.stringify({ method: "initialized", params: {} }));
  for (const [method, params] of steps) {
    if (method === "__wait") { await new Promise((r) => setTimeout(r, params * 1000)); console.log("waited", params, "s"); continue; }
    const r = await call(method, params);
    const out = r.error ? "ERROR " + JSON.stringify(r.error).slice(0, 200) : "ok " + JSON.stringify(r.result).slice(0, 160);
    console.log(method, "->", out);
    if (method === "turn/start" && !r.error) {
      const done = await new Promise((res) => { turnDone = res; setTimeout(() => res(null), 120000); });
      console.log("  turn/completed:", done ? done.params.turn.status : "timeout");
    }
  }
  ws.close(); process.exit(0);
});
ws.on("error", (e) => { console.log("ws error", e.message); process.exit(1); });
