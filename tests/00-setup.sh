#!/usr/bin/env bash
# Creates the throwaway test agent on the codex-shared provider (thread/start + first turn).
. "$(dirname "$0")/lib.sh"; cd "$BT_DIR"
TITLE="bridge-test-$(date +%s)"
paseo run --provider codex-shared --mode auto --title "$TITLE" --label test=bridge \
  "只回复这一行：T1-ok。不要运行任何命令。" >/dev/null 2>&1
ID=$(paseo ls 2>/dev/null | awk -v t="$TITLE" '$2==t{print $1}'); ID=$(paseo inspect "$ID" 2>/dev/null | awk '/^Id/{print $2}')
echo "$ID" > "$STATE/agent.id"; thread_of "$ID" > "$STATE/thread.id"
echo "agent=$(agent) thread=$(thread)"
check "new agent replies" "tl $ID 3 | grep -q T1-ok"
check "new agent idle" "[ \"\$(st $ID)\" = idle ]"
# The writer lock must be held by the shared app-server (started with --listen), not a private one.
HOLDER=$(lslocks -n -o PID,PATH 2>/dev/null | awk -v t="$(thread)" 'index($2,t){print $1; exit}')
check "thread lock held by the shared app-server" "[ -n \"$HOLDER\" ] && tr '\\0' ' ' < /proc/$HOLDER/cmdline | grep -q -- '--listen'"
timeout 120 paseo send "$ID" "只回复这一行：T2-ok。不要运行任何命令。" >/dev/null 2>&1
check "follow-up turn" "tl $ID 3 | grep -q T2-ok"
exit ${FAILED:-0}
