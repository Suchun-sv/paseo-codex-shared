# paseo-codex-shared

Lets [Paseo](https://paseo.sh) drive Codex threads that are already open in Codex Desktop
(or ChatGPT desktop) on a remote host, without stopping Desktop.

## Problem

Codex Desktop reaches a remote host over SSH and talks to one long-lived
`codex app-server` through `codex app-server proxy`. That server holds a writer lock
(`flock` on `~/.codex/thread-writer-locks/<thread>.lock`) for every thread it has loaded,
for as long as it stays loaded — not just while a turn runs.

Paseo's Codex provider spawns its own `codex app-server` per agent. Importing or resuming a
thread that Desktop has loaded therefore fails with
`thread <id> already has an active writer`.

## How it works

`codex-shared-bridge` is a drop-in replacement for the `codex` binary, registered as a Paseo
provider (`codex-shared`, extends `codex`):

- `codex-shared-bridge app-server …` connects to the shared server's control socket
  (`~/.codex/app-server-control/app-server-control.sock`, which speaks WebSocket) and bridges
  it to the JSONL-over-stdio protocol Paseo expects. Paseo becomes one more client of the
  server Desktop uses, so no second writer exists.
- Any other invocation (`--version`, …) is passed to the real `codex`.

One protocol gap is patched in the bridge: Paseo skips `thread/resume` for threads listed by
`thread/loaded/list`, because on its own server "loaded" means "loaded by me". On a shared
server the thread was loaded by Desktop, so Paseo's connection is not subscribed and never
receives `item/*` or `turn/*` events — the agent sits in `running` forever. Before forwarding
`turn/start`, `turn/steer`, `turn/interrupt`, `thread/compact/start`, … for a thread this
connection has not subscribed to, the bridge sends its own
`thread/resume {threadId, excludeTurns: true}` and swallows the reply. Only
`thread/start|resume|fork` results count as subscribed (`thread/read` does not).

## Install

```bash
./install.sh            # current user on this machine
./install.sh myhost     # over ssh
./install.sh --log myhost   # also write per-connection frame logs (full conversation content)
```

It installs `~/.local/bin/codex-shared-bridge`, backs up `~/.paseo/config.json`, and merges a
`codex-shared` entry into `agents.providers`. The provider applies live; no daemon restart.

Then pick **Codex (shared backend)** when creating an agent, or import a Desktop thread:

```bash
paseo import <codex-thread-id> --provider codex-shared --cwd <dir>
```

Environment knobs: `CODEX_HOME`, `CODEX_REAL_BIN`, `CODEX_CONTROL_SOCKET`, `PASEO_CLI_DIR`
(where the `ws` module is borrowed from), `CODEX_BRIDGE_LOG_DIR`.

## Tests

End-to-end, run on the Paseo host against a throwaway agent in `$BT_DIR`
(default `~/paseo-test/bridge-test`):

```bash
tests/run-all.sh
```

| Script | Covers |
|---|---|
| `00-setup.sh` | new agent (`thread/start`), lock held by the shared server, follow-up turn |
| `10-approvals-and-controls.sh` | approval allow / deny, interrupt, steer, mode switch, thinking change |
| `20-resilience.sh` | bridge killed → reconnect, `paseo agent reload`, another client's turn, `/compact` |
| `30-approval-broadcast.sh` | approval requests reach every subscribed client |
| `90-teardown.sh` | archive (archives the codex thread too), delete |

`tools/fake-client.mjs` is a minimal second client of the shared server (stands in for
Desktop); `tools/decode-log.py` summarises a frame log.

## Behaviour that differs from Paseo's own app-server

- **Approvals are broadcast.** Every client subscribed to the thread gets the request; whoever
  answers first wins. Desktop can resolve an approval that Paseo started.
- **Interrupted background commands survive.** They are children of the shared server, so
  closing the Paseo agent does not reap them.
- **Archive/delete in Paseo archives the codex thread**, which Desktop then shows as archived.
  This is normal Paseo behaviour, but matters more for threads you also use in Desktop.
- **Depends on the shared server.** If Desktop's app-server is not running, the bridge cannot
  connect.
- **Rewind does not work** with codex 0.162.x: Paseo calls `thread/rollback`, which that codex
  no longer has. Unrelated to the bridge.

Tested with Paseo 0.15.4 and codex-cli 0.162.1.
