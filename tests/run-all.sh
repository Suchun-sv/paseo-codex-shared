#!/usr/bin/env bash
# Runs the whole suite in order on the Paseo host. Uses a throwaway agent in $BT_DIR.
cd "$(dirname "$0")"; rc=0
for t in 00-setup.sh 10-approvals-and-controls.sh 20-resilience.sh 30-approval-broadcast.sh 90-teardown.sh; do
  echo "### $t"; bash "$t" || rc=1
done
exit $rc
