#!/bin/zsh
# startstop.sh <ios|android> <out> : one runner start --detach --json / runner stop --json cycle with session.json polling and ps checks
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke4/env.sh
plat=$1 out=$2
if [[ $plat == android ]]; then cd $S/demo/android; tgt=(--device $SER); key=$SER; else cd $S/demo/ios; tgt=(--simulator $UDID); key=$UDID; fi
exec > $out 2>&1
echo "# $(date +%H:%M:%S.%3N 2>/dev/null || date +%H:%M:%S) $(uptime)"
echo "## sessions before"; ls -la /tmp/grantiva-sessions; ls .grantiva 2>/dev/null
echo "\$ $GRANTIVA runner start $tgt --detach --json"
t0=$(perl -MTime::HiRes=time -e 'printf "%.2f", time')
$GRANTIVA runner start $tgt --detach --json > $S/start.out 2> $S/start.err &
sp=$!
last=""
while kill -0 $sp 2>/dev/null; do
  if [[ -f .grantiva/session.json ]]; then cur=$(cat .grantiva/session.json); if [[ "$cur" != "$last" ]]; then echo "## session.json at +$(perl -MTime::HiRes=time -e "printf '%.2f', time-$t0") s"; echo "$cur"; last=$cur; fi; fi
  sleep 0.3
done
wait $sp; rc=$?
echo "## start stdout (exit $rc, +$(perl -MTime::HiRes=time -e "printf '%.2f', time-$t0") s)"; cat $S/start.out; echo "## start stderr"; cat $S/start.err
echo "## session.json after start returned"; cat .grantiva/session.json
echo "## sessions during"; ls -la /tmp/grantiva-sessions
echo "## processes naming $key (during)"; ps -axo pid,ppid,etime,command | grep -F $key | grep -v grep | cut -c1-250
echo "\$ $GRANTIVA runner stop --json"
$GRANTIVA runner stop --json; echo "# stop exit $?"
echo "## +0 s processes naming $key"; ps -axo pid,ppid,etime,command | grep -F $key | grep -v grep | cut -c1-250
echo "## grantiva-runner / uia2 processes"; ps -axo pid,ppid,command | grep -E "grantiva-runner|xcodebuild" | grep -v grep | cut -c1-250
sleep 60
echo "## +60 s processes naming $key"; ps -axo pid,ppid,etime,command | grep -F $key | grep -v grep | cut -c1-250
echo "## grantiva-runner processes +60"; ps -axo pid,ppid,command | grep -E "grantiva-runner|xcodebuild" | grep -v grep | cut -c1-250
echo "## sessions after"; ls -la /tmp/grantiva-sessions; ls -la .grantiva 2>/dev/null
[[ $plat == android ]] && { echo "## adb forwards"; adb -s $SER forward --list; echo "## uia2 on device"; adb -s $SER shell 'ps -A | grep -i uiautomator'; }
echo "# end $(date +%H:%M:%S) $(uptime)"
