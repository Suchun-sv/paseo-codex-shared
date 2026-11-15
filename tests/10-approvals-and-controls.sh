#!/usr/bin/env bash
# Approvals (allow/deny), interrupt, steer, mode switch, thinking change.
. "$(dirname "$0")/lib.sh"; ID=$(agent)
CURL="curl -sS -m 8 -o /dev/null -w '%{http_code}'"
approve() { # $1 marker $2 allow|deny $3 url
  local before r i=0; before=$(pending_req "$ID")
  paseo send "$ID" --no-wait "请用 shell 运行：$CURL $3 。被沙箱拦住就申请提升权限。最后只回复一行：$1 加上结果（被拒绝就回复 $1 denied）。" >/dev/null 2>&1
  while [ $i -lt 90 ]; do r=$(pending_req "$ID"); [ -n "$r" ] && [ "$r" != "$before" ] && break; sleep 2; i=$((i+2)); done
  check "$1 approval request surfaces in Paseo" "[ -n \"$r\" ]"
  [ -n "$r" ] && paseo permit "$2" "$ID" "$r" >/dev/null 2>&1; waitidle "$ID" 150
}
approve T3 allow https://example.com;  check "T3 allowed command ran" "tl $ID 2 | grep -q 'T3.*200'"
approve T4 deny  https://example.org;  check "T4 denial honoured" "tl $ID 2 | grep -q -i 'T4.*denied\|T4.*拒'"

paseo send "$ID" --no-wait "运行 shell 命令 sleep 90，结束后回复 T5-finished。" >/dev/null 2>&1; sleep 12
paseo stop "$ID" >/dev/null 2>&1; waitidle "$ID" 40
check "T5 interrupt returns to idle" "[ \"\$(st $ID)\" = idle ]"
check "T5 interrupted turn did not finish" "! tl $ID 3 | grep -q T5-finished"
pkill -f 'sleep 90' 2>/dev/null   # interrupt leaves background exec running under the shared server

paseo send "$ID" --no-wait "运行 shell 命令 sleep 25，然后回复 T6-original。" >/dev/null 2>&1; sleep 8
paseo send "$ID" --behavior steer --no-wait "改主意了：不用等，直接只回复 T6-steered。" >/dev/null 2>&1; waitidle "$ID" 120
check "T6 steer applied" "tl $ID 4 | grep -q T6-steered"

paseo agent mode "$ID" full-access >/dev/null 2>&1
timeout 150 paseo send "$ID" "用 shell 运行 $CURL https://example.com ，只回复一行：T7 加上输出。" >/dev/null 2>&1
check "T7 full-access runs without a prompt" "[ -z \"\$(pending_req $ID)\" ] && tl $ID 2 | grep -q 'T7.*200'"
paseo agent mode "$ID" auto >/dev/null 2>&1

paseo agent update "$ID" --thinking low >/dev/null 2>&1
timeout 120 paseo send "$ID" "只回复：T8-ok" >/dev/null 2>&1
check "T8 reply after thinking change" "tl $ID 2 | grep -q T8-ok"
exit ${FAILED:-0}
