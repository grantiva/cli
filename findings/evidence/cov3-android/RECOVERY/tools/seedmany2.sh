#!/bin/bash
# seedmany2.sh <serial> <tag> [extra]: run 10-seed-many; print assert status, flow exit, and the landmark rows on screen right after the run (uiautomator dump: first..last, last fully visible)
s=$1; t=$2; shift 2
$GRANTIVA run --device $s --no-build --flow .maestro/10-seed-many.yaml --report-dir $S/sm-$t "$@" > $S/sm-$t.out 2> $S/sm-$t.err; rc=$?
adb -s $s shell uiautomator dump /sdcard/sm.xml >/dev/null 2>&1; adb -s $s shell cat /sdcard/sm.xml > $S/sm-$t.xml
python3 -I - "$S/sm-$t" "$S/sm-$t.xml" <<'PY'
import json,sys,re
d,x=sys.argv[1],sys.argv[2]
f=json.load(open(d+'/flows/flow-000.json'))
a=[c for c in f['commands'] if c['type']=='assertVisible'][0]
sc=[c.get('duration') for c in f['commands'] if c['type']=='scroll']
xml=open(x).read()
rows=[(int(n),int(y1),int(y2)) for n,y1,y2 in re.findall(r'text="Landmark (\d+)"[^>]*bounds="\[\d+,(\d+)\]\[\d+,(\d+)\]"',xml)]
full=[n for n,y1,y2 in rows if y2<=2064]
print('assert',a['status'],'scroll-ms',sc,'on-screen',(min(r[0] for r in rows),max(r[0] for r in rows)) if rows else '-','last-full',max(full) if full else '-')
PY
echo "exit $rc"
