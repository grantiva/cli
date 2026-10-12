#!/bin/zsh
# td-run.sh <N>: round-3 confirmation TD-ios run N (copy of round3-resmoke/fg-teardown.sh, iOS only, with
# a fresh simulator per run, a sessions-dir poll that runs its full 10 s and writes directly (no pipeline to kill),
# and the 10 s post-teardown checks of L63)
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke6/env.sh
N=$1; ev=$E/run-$N; mkdir -p $ev; A=$S/demo/ios; B=$S/empty-B
hdr() { echo "\$ (cwd $PWD) $*"; echo "# start $(now) $(uptime)"; }
cd $A
{ hdr $GRANTIVA simulator ensure --name smoke6-ios --device-type "iPhone 17" --runtime "iOS 26.0"; $GRANTIVA simulator ensure --name smoke6-ios --device-type "iPhone 17" --runtime "iOS 26.0"; echo "# exit $?  end $(now)"; } > $ev/ensure.txt 2>&1
UDID=$(grep -Eo '^[0-9A-F-]{36}$' $ev/ensure.txt | tail -1)
[[ -z $UDID ]] && { echo "no udid"; cat $ev/ensure.txt; exit 2; }
echo $UDID > $ev/udid.txt
{ hdr $GRANTIVA build install --simulator $UDID --no-launch; $GRANTIVA build install --simulator $UDID --no-launch; echo "# exit $?  end $(now)"; } > $ev/build-install.txt 2>&1
{ echo "## booted before $(now)"; xcrun simctl list devices booted; echo "## sessions dir"; ls -la /tmp/grantiva-sessions; echo "## device homes"; ls -la $DH; } > $ev/before.txt 2>&1
out=$ev/fg-start.txt
{ echo "\$ (cwd $PWD) $GRANTIVA runner start --simulator $UDID   (foreground, backgrounded by this script)"; echo "# start $(now) $(uptime)"; } > $out
$GRANTIVA runner start --simulator $UDID >> $out 2>&1 &
sp=$!
for k in $(seq 1 600); do grep -q '^Runner started' $out && break; kill -0 $sp 2>/dev/null || break; sleep 0.2; done
echo "# ready seen $(now)" > $ev/ready.txt
{ echo "## session.json"; cat .grantiva/session.json; echo; echo "## sessions dir before teardown"; ls -la /tmp/grantiva-sessions; } > $ev/before-teardown.txt 2>&1
# sessions-dir poll: every 0.1 s for 10 s, written directly; consecutive duplicate listings collapsed afterwards
( t0=$(perl -MTime::HiRes=time -e 'print time'); while :; do echo "$(now) [$(ls /tmp/grantiva-sessions 2>/dev/null | tr '\n' ' ')]"; perl -MTime::HiRes=time -e "exit(time-$t0>=10?0:1)" && break; sleep 0.1; done > $ev/sessions-dir-poll.raw ) &
pp=$!
cd $B
t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
{ hdr $GRANTIVA simulator teardown --udid $UDID --json; } > $ev/teardown.txt
$GRANTIVA simulator teardown --udid $UDID --json > $ev/teardown.json 2> $ev/teardown.stderr; trc=$?
t1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
tw=$(echo "$t1 - $t0" | bc)
{ echo "## stderr"; cat $ev/teardown.stderr; echo "## stdout"; cat $ev/teardown.json; echo "# exit $trc"; echo "# wall $tw s; end $(now) $(uptime)"; } >> $ev/teardown.txt
# wait for the start, at most 120 s
for k in $(seq 1 600); do kill -0 $sp 2>/dev/null || break; sleep 0.2; done
if kill -0 $sp 2>/dev/null; then echo "# start still running 120 s after teardown $(now)" >> $out; fi
wait $sp; rc=$?; echo "# exit $rc  end $(now) $(uptime)" >> $out
wait $pp; awk '{l=$0; sub(/^[^ ]+ /,"",l); if (l!=p) print; p=l}' $ev/sessions-dir-poll.raw > $ev/sessions-dir-poll.txt; rm $ev/sessions-dir-poll.raw
# 10 s after the teardown returned
perl -MTime::HiRes=time,sleep -e "\$d=$t1+10-time; sleep(\$d) if \$d>0"
{ echo "# checks at $(now) (teardown returned at +$tw s; checks >= 10 s later)"; echo "## uptime"; uptime
  echo "## device home $DH/$UDID"; if [[ -e $DH/$UDID ]]; then echo "EXISTS"; du -sh $DH/$UDID; find $DH/$UDID | head -20; else echo "absent"; fi
  echo "## /tmp/grantiva-sessions"; ls -la /tmp/grantiva-sessions
  echo "## processes whose argv names $UDID"; ps -axo pid,ppid,etime,command | grep -F $UDID | grep -v 'grep -F'
  echo "## simctl"; xcrun simctl list devices | grep -F smoke6; xcrun simctl list devices booted
} > $ev/after-10s.txt 2>&1
python3 -I - $ev <<'PY' > $ev/summary.txt
import json,sys,os
ev=sys.argv[1]
j=json.load(open(ev+'/teardown.json'))
d=j[0] if isinstance(j,list) else j
st=open(ev+'/fg-start.txt').read().splitlines()
last=[l for l in st if not l.startswith('#') and l.strip()][-1]
err=open(ev+'/teardown.stderr').read()
a=open(ev+'/after-10s.txt').read()
print("deleted:",d.get('deleted'))
print("runnerSessionStopped:",d.get('runnerSessionStopped'))
print("leftoverProcesses:",json.dumps(d.get('leftoverProcesses')))
print("reapedProcesses:",json.dumps(d.get('reapedProcesses')))
print("killed:",json.dumps(d.get('killed')))
print("other keys:",sorted(k for k in d if k not in('session',)))
print("warning lines:",[l for l in err.splitlines() if 'Warning' in l])
print("start final line:",last)
PY
echo "$(cat $ev/udid.txt) teardown rc=$trc wall=$tw start rc=$rc"; cat $ev/summary.txt; grep -n . $ev/sessions-dir-poll.txt; cat $ev/after-10s.txt
