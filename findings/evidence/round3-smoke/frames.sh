#!/bin/zsh
# frames.sh <ios|android> : keep-alive 01-browse, hierarchy --format json (+ runner dump-hierarchy on Android), check frame value types, SIGINT own run
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke4/env.sh
plat=$1; ev=$E/$( [[ $plat == android ]] && echo A || echo I )-frames; mkdir -p $ev
if [[ $plat == android ]]; then cd $S/demo/android; tgt=(--device $SER); key=$SER; else cd $S/demo/ios; tgt=(--simulator $UDID); key=$UDID; fi
$GRANTIVA run $tgt --no-build --flow .maestro/01-browse.yaml --keep-alive > $ev/keepalive-run.txt 2>&1 &
rp=$!
until grep -q "Press Ctrl-C to release" $ev/keepalive-run.txt; do sleep 0.5; kill -0 $rp 2>/dev/null || break; done
rec $ev/hierarchy.txt $GRANTIVA hierarchy --udid $key --format json
sed -n '3,$p' $ev/hierarchy.txt | sed '/^# exit/,$d' > $S/h-$plat.json
python3 -I - $S/h-$plat.json > $ev/frame-types.txt <<'PY'
import json,sys,collections
d=json.load(open(sys.argv[1])); c=collections.Counter(); ex=[]
def walk(n):
    if isinstance(n,dict):
        f=n.get('frame')
        if isinstance(f,dict):
            for k,v in f.items(): c[(k,type(v).__name__)]+=1
            if len(ex)<3: ex.append(f)
        for v in n.values(): walk(v)
    elif isinstance(n,list):
        for v in n: walk(v)
walk(d); print("frame value types:",dict(c)); print("examples:",ex)
PY
echo "kill -INT $rp (own run) $(date +%H:%M:%S)" >> $ev/keepalive-run.txt; kill -INT $rp; wait $rp; echo "# exit $?" >> $ev/keepalive-run.txt
cat $ev/frame-types.txt; tail -2 $ev/keepalive-run.txt
