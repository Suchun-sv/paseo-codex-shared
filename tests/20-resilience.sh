#!/usr/bin/env bash
# Reconnects, reload, a second client driving the same thread, compaction.
. "$(dirname "$0")/lib.sh"; ID=$(agent); TH=$(thread)
pkill -f "codex-shared-bridge app-server"; sleep 3
timeout 150 paseo send "$ID" "只回复：R1-ok" >/dev/null 2>&1
check "R1 send after bridge loss" "tl $ID 2 | grep -q R1-ok"
paseo agent reload "$ID" >/dev/null 2>&1
timeout 150 paseo send "$ID" "只回复：R2-ok" >/dev/null 2>&1
check "R2 send after reload" "tl $ID 2 | grep -q R2-ok"
$FAKE_CLIENT "[[\"thread/resume\",{\"threadId\":\"$TH\",\"excludeTurns\":true}],[\"turn/start\",{\"threadId\":\"$TH\",\"input\":[{\"type\":\"text\",\"text\":\"只回复：R4-foreign\",\"text_elements\":[]}]}]]" >/dev/null
sleep 3
check "R4 another client's turn shows in Paseo" "tl $ID 3 | grep -q R4-foreign"
check "R4 Paseo returns to idle" "[ \"\$(st $ID)\" = idle ]"
timeout 200 paseo send "$ID" "/compact" >/dev/null 2>&1; waitidle "$ID" 120
timeout 150 paseo send "$ID" "只回复：R5-after" >/dev/null 2>&1
check "R5 works after /compact" "tl $ID 2 | grep -q R5-after"
exit ${FAILED:-0}
