#!/bin/bash
# crashrun.sh <tag> <flow>: timed run of a crash flow; evidence in $E/CF-<tag>/ plus the last am_crash event and the first failing command
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/env.sh
tag=$1; flow=$2; d=$E/CF-$tag; mkdir -p $d; rm -rf $S/cf/$tag; cd $P
up=$(uptime | sed 's/.*load averages*: //')
/usr/bin/time -p $GRANTIVA run --device emulator-5554 --no-build --flow $flow --report-dir $S/cf/$tag > $d/run.out 2> $d/run.err; rc=$?
adb -s emulator-5554 logcat -b events -d -s am_crash | tail -1 > $d/am_crash.txt
printf '# cwd=%s load=%s\n$ /usr/bin/time -p $GRANTIVA run --device emulator-5554 --no-build --flow %s --report-dir $S/cf/%s\nrc=%s (run.out, run.err; wall in run.err "real"; am_crash.txt = last am_crash event; report/)\n\n' "$PWD" "$up" "$flow" "$tag" "$rc" >> $d/commands.txt
mkdir -p $d/report; cp $S/cf/$tag/report.json $S/cf/$tag/client.log $S/cf/$tag/maestro-runner.log $d/report/ 2>/dev/null; cp $S/cf/$tag/flows/*.json $d/report/ 2>/dev/null
python3 -I - "$S/cf/$tag" "$d/am_crash.txt" "$tag" "$(grep '^real' $d/run.err)" <<'PY'
import json,sys,re,datetime
d,am,tag,real=sys.argv[1:5]
try: f=json.load(open(d+'/flows/flow-000.json'))
except Exception as e: print(tag,'no report',e); sys.exit()
a=open(am).read().strip()
m=re.match(r'(\d\d-\d\d) (\d\d:\d\d:\d\d\.\d+)',a)
out=[]
for c in f['commands']:
    out.append('%s:%s:%s:%s'%(c.get('type'),c.get('status'),c.get('duration'),(c.get('error') or {}).get('type')))
fail=[c for c in f['commands'] if c.get('status')=='failed']
gap=''
if fail and m:
    end=fail[0].get('endTime'); 
    ct=datetime.datetime.strptime('2026-'+m.group(1)+' '+m.group(2)[:15],'%Y-%m-%d %H:%M:%S.%f')
    et=datetime.datetime.fromisoformat(end).replace(tzinfo=None)
    gap='crash->fail %.1fs'%(et-ct).total_seconds()
print(tag,real,'flow',f.get('duration'),'|',' '.join(out),'|',gap)
PY
