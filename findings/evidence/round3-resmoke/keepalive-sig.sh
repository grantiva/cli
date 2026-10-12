#!/bin/zsh
# keepalive-sig.sh <ios|android> <flow> <outdir> <name> <mode: during|after>   (round-3 script + --ready-file and a 'stop sent' timestamp)
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke5/env.sh
plat=$1 flow=$2 ev=$3 name=$4 mode=$5
if [[ $plat == android ]]; then cd $S/demo/android; tgt=(--device $SER); else cd $S/demo/ios; tgt=(--simulator $UDID); fi
mkdir -p $ev; out=$ev/$name-run.txt; rf=$S/ready-$plat-$name.json; rm -f $rf
{ echo "\$ $GRANTIVA run $tgt --no-build --flow $flow --keep-alive --ready-file $rf   (mode: stop $mode the flow)"; echo "# start $(date +%H:%M:%S) $(uptime)"; } > $out
$GRANTIVA run $tgt --no-build --flow $flow --keep-alive --ready-file $rf >> $out 2>&1 &
rp=$!
if [[ $mode == during ]]; then
  until grep -q "launchApp" $out; do sleep 0.5; kill -0 $rp 2>/dev/null || break; done; sleep 8
else
  until grep -q "Press Ctrl-C to release" $out; do sleep 0.5; kill -0 $rp 2>/dev/null || break; done; sleep 3
fi
{ echo "## sessions during"; ls -la /tmp/grantiva-sessions; ls .grantiva; echo "== ready file before stop"; cat $rf 2>&1; echo; } > $ev/$name-during.txt 2>&1
t0=$(perl -MTime::HiRes=time -e 'printf "%.2f", time')
{ echo "kill -INT $rp (the grantiva run started by this script) at $(date +%H:%M:%S)"; kill -INT $rp; } > $ev/$name-stop.txt 2>&1
wait $rp; rc=$?
t1=$(perl -MTime::HiRes=time -e 'printf "%.2f", time')
echo "# exit $rc"; echo "# exit $rc  end $(date +%H:%M:%S) (run ended $(echo "$t1 - $t0" | bc) s after the stop was sent) $(uptime)" >> $out
{ echo "## sessions after"; ls -la /tmp/grantiva-sessions; ls -la .grantiva; echo "== ready file $rf"; cat $rf; echo; echo "## grantiva-runner/xcodebuild processes"; ps -axo pid,ppid,command | grep -E "grantiva-runner|xcodebuild|grantiva run" | grep -v grep | cut -c1-200; } > $ev/$name-after.txt 2>&1
