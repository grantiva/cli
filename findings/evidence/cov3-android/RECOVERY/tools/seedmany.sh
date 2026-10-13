#!/bin/bash
# seedmany.sh <serial> <tag> [extra]: run 10-seed-many and print the landmark numbers visible after the 4 scrolls
s=$1; t=$2; shift 2
$GRANTIVA run --device $s --no-build --flow .maestro/10-seed-many.yaml --report-dir $S/sm-$t "$@" > /dev/null 2>&1; rc=$?
python3 -I - "$S/sm-$t" <<'PY'
import json,sys,re,glob
d=sys.argv[1]
f=json.load(open(d+'/flows/flow-000.json'))
x=[c for c in f['commands'] if c['type']=='assertVisible'][0]
h=glob.glob(d+'/assets/flow-000/*hierarchy.xml')
nums=sorted(set(int(n) for n in re.findall(r'Landmark (\d+)', open(h[0]).read()))) if h else []
print('assert', x['status'], 'visible-after-fail', (nums[0],nums[-1]) if nums else '-')
PY
echo "exit $rc"
