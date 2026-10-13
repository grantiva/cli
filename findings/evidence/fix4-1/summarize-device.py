from pathlib import Path
import datetime,json,re
base=Path(__file__).parent
rows=[]
def epoch(value):return datetime.datetime.fromisoformat(value).timestamp()
for n in range(4,9):
 d=base/f'stock-{n}'
 flow=json.loads(next((d/'report/flows').glob('*.json')).read_text())
 launch=flow['commands'][0]
 log=(d/'logcat.txt').read_text(errors='replace')
 fatals=[];pid=None
 for line in log.splitlines():
  if 'FATAL EXCEPTION' in line and 'AndroidRuntime' in line:
   m=re.match(r'\s*(\d+\.\d+)\s+(\d+)\s+',line)
   if m:fatals.append((float(m[1]),m[2]))
 fatal,pid=fatals[0]
 assert f'Process: com.kylebrowning.landmarks, PID: {pid}' in log
 assert launch['status']=='failed' and launch['error']['type']=='app_crash',launch
 decision=epoch(launch['endTime'])
 before=json.loads((d/'clock-before.json').read_text());after=json.loads((d/'clock-after.json').read_text())
 # Hull of the bracketing clock probes: device sample was taken at an
 # unknown instant within each host round trip; retain the full uncertainty.
 offsets=[(x['deviceEpoch']-x['hostAfter'],x['deviceEpoch']-x['hostBefore']) for x in (before,after)]
 offsetLo=min(x[0] for x in offsets);offsetHi=max(x[1] for x in offsets)
 deltaLo=decision-fatal+offsetLo;deltaHi=decision-fatal+offsetHi
 runner=(d/'report/maestro-runner.log').read_text()
 starts={};ends={}
 for line in runner.splitlines():
  m=re.search(r'failure artifact (\w+) (started|finished) at (\S+)',line)
  if m:(starts if m[2]=='started' else ends)[m[1]]=epoch(m[3])
 assert len(starts)==len(ends)==3,(starts,ends)
 duration=max(ends.values())-min(starts.values())
 result=json.loads((d/'result.json').read_text())
 assert deltaHi<=2,(n,deltaHi)
 assert duration<=2.25,(n,duration)
 assert not result['collectorProcessesAfter']
 artifacts=[]
 for f in [p for area in ['assets','captures'] for p in (d/'report'/area).rglob('*')]:
  if f.is_file():artifacts.append({'path':str(f.relative_to(d)),'mtimeEpoch':f.stat().st_mtime,'bytes':f.stat().st_size})
 lastArtifact=max(a['mtimeEpoch'] for a in artifacts)-decision
 assert lastArtifact<=2.25,lastArtifact
 rows.append({'failureToLastArtifactSeconds':lastArtifact,'run':d.name,'load1':json.loads((d/'command.json').read_text())['loadBefore'],'fatalPID':pid,'fatalDeviceEpoch':fatal,'decisionHostEpoch':decision,'rawCrossClockDifferenceSeconds':decision-fatal,'offsetIntervalSeconds':[offsetLo,offsetHi],'fatalToDecisionIntervalSeconds':[deltaLo,deltaHi],'collectorStartHostEpochs':starts,'collectorEndHostEpochs':ends,'captureDurationSeconds':duration,'failureToLastCollectorSeconds':max(ends.values())-decision,'artifacts':artifacts,'launchStatus':launch['status'],'errorType':launch['error']['type'],'collectorProcessesAfter':result['collectorProcessesAfter']})
summary={'method':'Conservative hull of host-before/device-epoch/host-after clock probes immediately before and after each run; raw timestamps retained. Bounds assume device/host offset stays within the observed bracketing interval. No negative raw difference treated as latency.','runs':rows,'allFivePassed':True,'maxFatalToDecisionUpperBoundSeconds':max(r['fatalToDecisionIntervalSeconds'][1] for r in rows),'maxCaptureDurationSeconds':max(r['captureDurationSeconds'] for r in rows),'maxFailureToLastArtifactSeconds':max(r['failureToLastArtifactSeconds'] for r in rows)}
(base/'acceptance-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='runs'},indent=2))
for r in rows:print(r['run'],'fatal-to-decision',r['fatalToDecisionIntervalSeconds'],'capture',r['captureDurationSeconds'])
