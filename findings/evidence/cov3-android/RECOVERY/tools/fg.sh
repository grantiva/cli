#!/bin/bash
# fg.sh <outprefix> <end: int|stop> [extra args]: foreground runner start; wait for dump-hierarchy; end it by SIGINT or runner stop; report exit and leftovers
out=$1; how=$2; shift 2
$GRANTIVA runner start --device emulator-5554 "$@" > $out.out 2> $out.err & pid=$!
for i in $(seq 1 60); do $GRANTIVA runner dump-hierarchy --format tree > $out.dump 2>/dev/null && break; sleep 2; done
echo "dump-hierarchy from another shell: lines=$(wc -l < $out.dump) after ~$((i*2))s; foreground pid $pid alive=$(kill -0 $pid 2>/dev/null && echo yes || echo no)"
rp=$(python3 -I -c "import json;print(json.load(open('.grantiva/session.json'))['pid'])" 2>/dev/null); echo "runner pid $rp"
if [ $how = int ]; then kill -INT $pid; else $GRANTIVA runner stop; fi
wait $pid; echo "foreground exit $?"
sleep 1; echo "session.json: $(ls .grantiva/session.json 2>&1)"; echo "session files for runner: [$(ls /tmp/grantiva-sessions | grep "^$rp[-.]" | tr '\n' ' ')]"; echo "runner alive: $(kill -0 $rp 2>/dev/null && echo yes || echo no)"
echo "stdout lines $(wc -l < $out.out), stderr lines $(wc -l < $out.err)"
