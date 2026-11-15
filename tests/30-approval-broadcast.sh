#!/usr/bin/env bash
# Approval requests go to every client subscribed to the thread.
. "$(dirname "$0")/lib.sh"; ID=$(agent); TH=$(thread)
$FAKE_CLIENT "[[\"thread/resume\",{\"threadId\":\"$TH\",\"excludeTurns\":true}],[\"__wait\",45]]" > "$STATE/fake.out" 2>&1 &
FP=$!; sleep 3
paseo send "$ID" --no-wait "请用 shell 运行：curl -sS -m 8 -o /dev/null -w '%{http_code}' https://example.net 。被沙箱拦住就申请提升权限。最后只回复一行：A1 加上结果。" >/dev/null 2>&1
i=0; r=""; while [ $i -lt 60 ]; do r=$(pending_req "$ID"); [ -n "$r" ] && break; sleep 2; i=$((i+2)); done
paseo permit allow "$ID" "$r" >/dev/null 2>&1; wait $FP; waitidle "$ID" 90
check "A1 request also reached the other client" "grep -q 'server request to this client.*requestApproval' $STATE/fake.out"
check "A1 allow from Paseo worked" "tl $ID 2 | grep -q 'A1.*200'"
check "A1 no stale pending in Paseo" "[ -z \"\$(pending_req $ID)\" ]"
exit ${FAILED:-0}
