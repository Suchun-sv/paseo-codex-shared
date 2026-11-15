#!/usr/bin/env bash
# Install the bridge and register the `codex-shared` Paseo provider.
#   ./install.sh [--log] [ssh-host]
# Without a host it installs for the current user; with one it copies itself over ssh
# and runs there. --log turns on the per-connection frame log (full conversation content).
set -euo pipefail
LOG=0; HOST=""
for a in "$@"; do case $a in --log) LOG=1;; -h|--help) sed -n 2,5p "$0"; exit 0;; *) HOST=$a;; esac; done
HERE=$(cd "$(dirname "$0")" && pwd)

if [ -n "$HOST" ]; then
  ssh "$HOST" 'mkdir -p ~/.cache/paseo-codex-shared'
  scp -q "$HERE/codex-shared-bridge" "$HERE/install.sh" "$HOST:.cache/paseo-codex-shared/"
  exec ssh "$HOST" "bash ~/.cache/paseo-codex-shared/install.sh $([ $LOG = 1 ] && echo --log)"
fi

export PATH=$HOME/.local/bin:$PATH
[ -z "${PASEO_PASSWORD:-}" ] && [ -f "$HOME/.paseo/password.txt" ] && export PASEO_PASSWORD=$(cat "$HOME/.paseo/password.txt")
command -v paseo >/dev/null || { echo "paseo not found" >&2; exit 1; }
SOCK=${CODEX_HOME:-$HOME/.codex}/app-server-control/app-server-control.sock
[ -S "$SOCK" ] || echo "warning: no shared app-server socket at $SOCK yet (start Codex Desktop / connect once)" >&2

install -D -m 755 "$HERE/codex-shared-bridge" "$HOME/.local/bin/codex-shared-bridge"
CFG=$HOME/.paseo/config.json
cp -a "$CFG" "$CFG.bak-$(date +%Y%m%d-%H%M%S)"
PROVIDERS=$(LOG=$LOG BIN="$HOME/.local/bin/codex-shared-bridge" LOGDIR="$HOME/.codex-shared-bridge-logs" python3 - "$CFG" <<'PY'
import json, os, sys
providers = json.load(open(sys.argv[1])).get("agents", {}).get("providers", {})
entry = {
    "extends": "codex",
    "label": "Codex (shared backend)",
    "description": "Attaches to the running Codex Desktop app-server instead of spawning one",
    "command": [os.environ["BIN"]],
}
if os.environ["LOG"] == "1":
    entry["env"] = {"CODEX_BRIDGE_LOG_DIR": os.environ["LOGDIR"]}
providers["codex-shared"] = entry
print(json.dumps(providers))
PY
)
paseo daemon config set agents.providers "$PROVIDERS" >/dev/null
echo "installed: $HOME/.local/bin/codex-shared-bridge; provider codex-shared registered (log=$LOG)"
paseo provider ls 2>/dev/null | grep -E "^codex-shared" || true
