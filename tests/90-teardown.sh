#!/usr/bin/env bash
# Archive (also archives the codex thread — expected Paseo behaviour) then delete.
. "$(dirname "$0")/lib.sh"; ID=$(agent); TH=$(thread)
paseo agent archive "$ID" >/dev/null 2>&1; sleep 4
check "archive also archived the codex thread" "find ${CODEX_HOME:-$HOME/.codex}/archived_sessions -name \"*$TH*\" | grep -q ."
paseo agent delete "$ID" >/dev/null 2>&1
check "agent deleted" "! paseo ls -a 2>/dev/null | grep -q ${ID:0:7}"
exit ${FAILED:-0}
