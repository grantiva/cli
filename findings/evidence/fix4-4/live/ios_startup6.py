from pathlib import Path
import os,json,subprocess,time,signal
r=Path(__file__).parent;s=json.loads((r/'state-fix6.json').read_text());i=s['ios'];d=r/'ios-startup-fix6';d.mkdir();binary=s['binary'];udid=i['udid'];project=Path(i['project']);session=project/'.grantiva/session.json';checks=[]
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4')
notice='[grantiva] received SIGINT — releasing simulator and reaping child processes'
def capture(label,args):
 p=subprocess.run(args,cwd=project,capture_output=True,timeout=30);(d/(label+'.command.json')).write_text(json.dumps(args)+'\n');(d/(label+'.out')).write_bytes(p.stdout);(d/(label+'.err')).write_bytes(p.stderr);return p
capture('stale-session-cleanup',[binary,'runner','stop','--json'])
for label,flags,action in [('plain',[],'interrupt'),('quiet',['--quiet'],'interrupt'),('json',['--json'],'interrupt'),('plain-repeat',[],'interrupt'),('quiet-repeat',['--quiet'],'interrupt'),('json-repeat',['--json'],'interrupt'),('death',[],'death'),('timeout',[],'timeout')]:
 args=[binary,'runner','start','--platform','ios','--simulator',udid,'--bundle-id','com.kylebrowning.Landmarks']+flags;(d/(label+'.command.json')).write_text(json.dumps(args)+'\n');p=subprocess.Popen(args,cwd=project,stdout=(d/(label+'.out')).open('wb'),stderr=(d/(label+'.err')).open('wb'),start_new_session=True);start=time.monotonic();doc=None
 try:
  while time.monotonic()-start<60:
   if session.exists():
    try:doc=json.loads(session.read_text())
    except json.JSONDecodeError:continue
    if doc['state']=='starting':break
   assert p.poll() is None,'early exit';time.sleep(.001)
  else:raise TimeoutError('starting doc')
  sig=signal.SIGINT if action=='interrupt' else signal.SIGKILL if action=='death' else signal.SIGSTOP;target=p.pid if action=='interrupt' else doc['pid'];sent=time.monotonic();os.kill(target,sig);record={'cliPID':p.pid,'session':doc,'signal':sig.name,'targetPID':target,'sentEpoch':time.time()};(d/(label+'.signal.json')).write_text(json.dumps(record,indent=2)+'\n');code=p.wait(timeout=90);text=(d/(label+'.err')).read_text();out=(d/(label+'.out')).read_text();record.update(exit=code,signalToExit=time.monotonic()-sent)
  (d/(label+'.result.json')).write_text(json.dumps(record,indent=2)+'\n')
  assert not session.exists()
  if action=='interrupt':
   assert code==130 and notice in text and 'Timed out waiting for WDA' not in text,(code,text)
   if flags:assert 'grantiva-runner' not in text+out and 'Received interrupt, cleaning up' not in text+out
  else:
   assert code==1 and 'Error:' in text and notice not in text,(code,text)
   if action=='timeout':assert record['signalToExit']>=59 and 'Timed out waiting for WDA' in text
  ps=capture(label+'-processes',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']).stdout.decode();assert not any(line.split()[0]==str(doc['pid']) for line in ps.splitlines()),'runner remains'
  leftovers=[str(x) for x in Path('/tmp/grantiva-sessions').glob('*') if x.name.startswith(str(doc['pid'])+'-') or x.name.startswith(str(doc['pid'])+'.')];assert not leftovers,leftovers
  lock=Path(s['runnerHome'])/'locks'/f'{udid}.lock';record['leaseFileContents']=lock.read_text() if lock.exists() else None;record['sharedFiles']=leftovers;checks.append(record);(d/(label+'.result.json')).write_text(json.dumps(record,indent=2)+'\n');print(label,code,record['signalToExit'],flush=True)
 finally:
  if p.poll() is None:
   if doc:
    try:os.kill(doc['pid'],signal.SIGCONT)
    except ProcessLookupError:pass
   os.kill(p.pid,signal.SIGINT);p.wait(timeout=20)
  (d/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
