# Shared helpers for the end-to-end tests. Source from a test script running on the
# Paseo host (the machine whose Codex Desktop app-server the bridge attaches to).
TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BT_DIR=${BT_DIR:-$HOME/paseo-test/bridge-test}       # cwd for the throwaway test agent
STATE=$BT_DIR/.state; mkdir -p "$STATE"
FAKE_CLIENT="node $TESTS_DIR/../tools/fake-client.mjs"
export PATH=$HOME/.local/bin:$PATH
[ -z "$PASEO_PASSWORD" ] && [ -f "$HOME/.paseo/password.txt" ] && export PASEO_PASSWORD=$(cat "$HOME/.paseo/password.txt")

st() { paseo inspect "$1" 2>/dev/null | awk '/^Status/{print $2}'; }
waitidle() { local id=$1 t=${2:-120} i=0; while [ $i -lt "$t" ]; do case $(st "$id") in idle|error) return 0;; esac; sleep 2; i=$((i+2)); done; return 1; }
# Agent lines of the timeline only, so prompts that contain the marker don't count.
tl() { paseo logs "$1" 2>/dev/null | grep -v '^\[User\]' | tail -"${2:-4}" | cut -c1-180; }
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; FAILED=1; fi; }
agent() { cat "$STATE/agent.id"; }
thread() { cat "$STATE/thread.id"; }
# Codex thread id Paseo persisted for an agent.
thread_of() { python3 - "$1" <<'PY'
import glob, json, os, sys
for f in glob.glob(os.path.expanduser(f"~/.paseo/agents/*/{sys.argv[1]}.json")):
    blob = json.dumps(json.load(open(f)))
    import re
    m = re.search(r'"(?:sessionId|nativeHandle)":\s*"([0-9a-f-]{36})"', blob)
    if m: print(m.group(1)); break
PY
}
# Newest pending permission request id for an agent ("" if none).
pending_req() { paseo permit ls --json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin); d = d if isinstance(d, list) else d.get('permissions', d.get('data', []))
ids = [x.get('requestId') or x.get('id') for x in d if sys.argv[1][:8] in json.dumps(x)]
print(ids[-1] if ids else '')" "$1" 2>/dev/null; }
