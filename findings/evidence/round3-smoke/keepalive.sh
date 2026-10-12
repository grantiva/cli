#!/bin/zsh
# keepalive.sh <ios|android> <flow> <outdir> <name> <mode: during|after>
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke4/env.sh
plat=$1 flow=$2 ev=$3 name=$4 mode=$5
if [[ $plat == android ]]; then cd $S/demo/android; tgt=(--device $SER); else cd $S/demo/ios; tgt=(--simulator $UDID); fi
mkdir -p $ev; out=$ev/$name-run.txt
{ echo "\$ $GRANTIVA run $tgt --no-build --flow $flow --keep-alive   (mode: stop $mode the flow)"; echo "# start $(date +%H:%M:%S) $(uptime)"; } > $out
$GRANTIVA run $tgt --no-build --flow $flow --keep-alive >> $out 2>&1 &
rp=$!
if [[ $mode == during ]]; then
  until grep -q "launchApp" $out; do sleep 0.5; kill -0 $rp 2>/dev/null || break; done; sleep 8
else
  until grep -q "Press Ctrl-C to release" $out; do sleep 0.5; kill -0 $rp 2>/dev/null || break; done; sleep 3
fi
{ echo "## sessions during"; ls -la /tmp/grantiva-sessions; ls .grantiva; ls -la /tmp/grantiva-sessions; echo; } > $ev/$name-during.txt 2>&1
{ echo "\$ $GRANTIVA runner stop   ($(date +%H:%M:%S))"; $GRANTIVA runner stop; echo "# exit $?"; } > $ev/$name-stop.txt 2>&1
wait $rp; rc=$?
echo "# exit $rc"; echo "# exit $rc  end $(date +%H:%M:%S) $(uptime)" >> $out
{ echo "## sessions after"; ls -la /tmp/grantiva-sessions; ls -la .grantiva; for f in .grantiva/*ready*(N); do echo "== $f"; cat $f; done; } > $ev/$name-after.txt 2>&1
