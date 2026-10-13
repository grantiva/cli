from pathlib import Path
import os,json,subprocess,time,shutil,sys
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());a=s['android'];project=Path(a['project']);binary=s['binary'];serial=a['serial'];adb=a['adb'];d=r/'android-lifecycle-attempt1';d.mkdir()
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4',ANDROID_HOME='/Users/kyle/Library/Android/sdk')
(r/'environment.json').write_text(json.dumps({k:os.environ.get(k) for k in ['GRANTIVA_RUNNER_HOME','MAESTRO_RUNNER_HOME','GRANTIVA_SESSION_ID','GRANTIVA_API_KEY']},indent=2)+'\n')
source=r.parent.parent/'fix4-5'/'mcp_client.py'
(r/'mcp_client.py').write_text(source.read_text().replace("'fix4-5'","'fix4-4'"))
from mcp_client import Client
checks=[];first=None;c=None;started=None
session=project/'.grantiva/session.json'
def command(label,args,expected=0,timeout=60):
 t=time.time();(d/(label+'.command.json')).write_text(json.dumps(args)+'\n')
 p=subprocess.run(args,cwd=project,capture_output=True,timeout=timeout)
 (d/(label+'.out')).write_bytes(p.stdout);(d/(label+'.err')).write_bytes(p.stderr);(d/(label+'.result.json')).write_text(json.dumps({'exit':p.returncode,'started':t,'ended':time.time()})+'\n')
 if expected is not None:assert p.returncode==expected,(label,p.returncode,p.stderr.decode())
 return p
try:
 c=Client(binary,str(project),'android',d/'mcp')
 before=c.call('tools/list',{});assert len(before['result']['tools'])==22;checks.append('22 tools before start')
 command('forwards-before',[adb,'-s',serial,'forward','--list'])
 args=[binary,'runner','start','--platform','android','--device',serial,'--application-id','com.kylebrowning.landmarks','--detach','--json'];(d/'first.command.json').write_text(json.dumps(args)+'\n')
 first=subprocess.Popen(args,cwd=project,stdout=(d/'first.out').open('wb'),stderr=(d/'first.err').open('wb'),start_new_session=True);(d/'first.pid').write_text(str(first.pid)+'\n')
 limit=time.monotonic()+90
 while time.monotonic()<limit:
  if session.exists():
   try:doc=json.loads(session.read_text())
   except json.JSONDecodeError:continue
   if doc.get('state')=='starting':break
  assert first.poll() is None, 'first exited before observed starting'
  time.sleep(.005)
 else:raise TimeoutError('genuine starting state')
 (d/'session-starting.json').write_text(json.dumps(doc,indent=2)+'\n');runnerpid=doc['pid']
 second=command('second-json',args);secondjson=json.loads(second.stdout);assert secondjson['status']=='already_running' and 'port' in secondjson and secondjson['port'] is None and secondjson['pid']==runnerpid
 plain=command('second-plain',args[:-1]);assert f'Runner already running (pid {runnerpid}, starting)' in plain.stdout.decode()
 ps=command('processes-starting',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']).stdout.decode();owners=[line for line in ps.splitlines() if 'grantiva-runner' in line and f'--device {serial}' in line];assert len(owners)==1,owners
 checks.append({'N3-03':'explicit null port, plain starting and no duplicate','runnerPID':runnerpid,'starting':doc,'second':secondjson})
 code=first.wait(timeout=120);returned=time.time();(d/'first.result.json').write_text(json.dumps({'exit':code,'returned':returned})+'\n');assert code==0,(d/'first.err').read_text()
 # No sleep or caller-side readiness poll before this operation.
 hierarchy=command('immediate-hierarchy',[binary,'runner','dump-hierarchy','--udid',serial,'--format','tree']);assert 'Landmarks' in hierarchy.stdout.decode(),hierarchy.stdout.decode()
 started=json.loads((d/'first.out').read_text());ready=json.loads(session.read_text());(d/'session-ready.json').write_text(json.dumps(ready,indent=2)+'\n')
 assert started['pid']==runnerpid==ready['pid'] and started['port']>0 and ready['state']=='ready' and ready['udid']==serial
 tools=c.call('tools/list',{});assert len(tools['result']['tools'])==22
 context=c.tool('grantiva_context',{});(d/'context.json').write_text(json.dumps(context,indent=2)+'\n');contexttext=c.text(context);assert str(runnerpid) in contexttext and serial in contexttext,contexttext
 tree=c.tool('grantiva_a11y_tree',{});assert not tree.get('result',{}).get('isError') and 'Landmarks' in c.text(tree)
 checks.append({'AND-127':'immediate app tree, 22 tools and matching context','runnerPID':runnerpid,'port':started['port'],'device':serial})
 stop=command('stop',[binary,'runner','stop','--json']);stopped=json.loads(stop.stdout);assert stopped['pid']==runnerpid and stopped['status']=='stopped'
 assert not session.exists()
 forwards=command('forwards-after',[adb,'-s',serial,'forward','--list']);assert serial not in forwards.stdout.decode()
 command('processes-after',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command='])
 try:os.kill(runnerpid,0)
 except ProcessLookupError:pass
 else:raise AssertionError('runner still alive after stop')
 leftovers=[str(p) for p in Path('/tmp/grantiva-sessions').glob('*') if p.name.startswith(str(runnerpid)+'.') or p.name.startswith(str(runnerpid)+'-')];assert not leftovers,leftovers
 checks.append({'stop':'same PID stopped, no project/shared session and no owned forward','document':stopped})
finally:
 if c:c.close()
 if session.exists():command('emergency-stop',[binary,'runner','stop','--json'],expected=None,timeout=40)
 if started and started.get('log') and Path(started['log']).exists():shutil.copyfile(started['log'],d/'daemon.log')
 (d/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps(checks,indent=2),flush=True)
