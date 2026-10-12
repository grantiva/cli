#!/bin/zsh
# fg-teardown.sh <ios|android>: foreground runner start, torn down from another cwd by the device teardown
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke4/env.sh
plat=$1; ev=$E/teardown; mkdir -p $ev
if [[ $plat == android ]]; then cd $S/demo/android; tgt=(--device $SER); td=($GRANTIVA emulator teardown --serial $SER --json); else cd $S/demo/ios; tgt=(--simulator $UDID); td=($GRANTIVA simulator teardown --udid $UDID --json); fi
out=$ev/$plat-fg-start.txt
{ echo "\$ (cwd $PWD) $GRANTIVA runner start $tgt   (foreground, backgrounded by this script)"; echo "# start $(date +%H:%M:%S) $(uptime)"; } > $out
$GRANTIVA runner start $tgt >> $out 2>&1 &
sp=$!
for k in $(seq 1 300); do grep -q '"state":"ready"' .grantiva/session.json 2>/dev/null && break; sleep 0.5; done
{ echo "## session.json"; cat .grantiva/session.json; echo; echo "## sessions dir before teardown"; ls -la /tmp/grantiva-sessions; } > $ev/$plat-before-teardown.txt 2>&1
( for k in $(seq 1 600); do ls /tmp/grantiva-sessions 2>/dev/null | sed "s/^/$(date +%H:%M:%S) /"; sleep 0.1; done | sort -u -k2 > $ev/$plat-sessions-dir-poll.txt ) &
pp=$!
cd $S/empty-usage
{ echo "\$ (cwd $PWD) ${td[*]}"; echo "# $(date +%H:%M:%S) $(uptime)"; "${td[@]}"; echo "# exit $?"; } > $ev/$plat-teardown.txt 2>&1
wait $sp; rc=$?; echo "# exit $rc  end $(date +%H:%M:%S) $(uptime)" >> $out
sleep 2; kill $pp 2>/dev/null; wait $pp 2>/dev/null
{ echo "## sessions dir after"; ls -la /tmp/grantiva-sessions; } > $ev/$plat-after.txt 2>&1
echo "start exit $rc"; tail -4 $out; cat $ev/$plat-teardown.txt; cat $ev/$plat-after.txt; cat $ev/$plat-sessions-dir-poll.txt
