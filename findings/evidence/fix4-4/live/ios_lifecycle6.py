from pathlib import Path
import os,json,subprocess,time,signal,shutil,threading,shlex
r=Path(__file__).parent;s=json.loads((r/'state-fix6.json').read_text());i=s['ios'];d=r/'ios-lifecycle-fix6';d.mkdir();b=s['binary'];u=i['udid'];project=Path(i['project']);session=project/'.grantiva/session.json';checks=[]
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4')
def cmd(label,args,expected=0):
 p=subprocess.run(args,cwd=project,capture_output=True,timeout=60);(d/(label+'.command.json')).write_text(json.dumps(args)+'\n');(d/(label+'.out')).write_bytes(p.stdout);(d/(label+'.err')).write_bytes(p.stderr);(d/(label+'.exit')).write_text(str(p.returncode)+'\n');assert p.returncode==expected,(label,p.stderr);return p
def capture_report(process, label):
 while process.poll() is None:
  try:
   doc=json.loads(session.read_text());argv=shlex.split(subprocess.check_output(['/bin/ps','-ww','-p',str(doc['pid']),'-o','command='],text=True))
   if '--output' in argv:
    report=Path(argv[argv.index('--output')+1]);(d/(label+'-runner-argv.json')).write_text(json.dumps(argv))
    if report.exists():shutil.copytree(report,d/(label+'-generated-report'),dirs_exist_ok=True)
    if Path(argv[-1]).exists():shutil.copy2(argv[-1],d/(label+'-generated-flow.yaml'))
  except (FileNotFoundError,json.JSONDecodeError,subprocess.CalledProcessError):pass
  time.sleep(.02)
args=[b,'runner','start','--platform','ios','--simulator',u,'--bundle-id','com.kylebrowning.Landmarks'];p=None
try:
 first=args+['--detach','--json'];(d/'first.command.json').write_text(json.dumps(first));p=subprocess.Popen(first,cwd=project,stdout=(d/'first.out').open('wb'),stderr=(d/'first.err').open('wb'),start_new_session=True);threading.Thread(target=capture_report,args=(p,'first'),daemon=True).start();deadline=time.monotonic()+120
 while time.monotonic()<deadline:
  if session.exists():
   doc=json.loads(session.read_text())
   if doc['state']=='starting':break
  assert p.poll() is None;time.sleep(.002)
 else:raise TimeoutError('starting')
 (d/'starting.json').write_text(json.dumps(doc,indent=2));second=json.loads(cmd('second-json',first).stdout);assert second['pid']==doc['pid'] and second['port'] is None and second['status']=='already_running';plain=cmd('second-plain',first[:-1]);assert f"Runner already running (pid {doc['pid']}, starting)" in plain.stdout.decode();ps=cmd('processes-starting',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']).stdout.decode();assert len([x for x in ps.splitlines() if 'grantiva-runner' in x and u in x])==1
 code=p.wait(timeout=600);(d/'first.exit').write_text(str(code));assert code==0,(d/'first.err').read_text();assert json.loads((d/'first-generated-report/report.json').read_text())['status']=='passed';ready=json.loads(session.read_text());started=json.loads((d/'first.out').read_text());(d/'ready.json').write_text(json.dumps(ready,indent=2));assert ready['pid']==doc['pid'] and ready['state']=='ready' and ready['port']>0
 hierarchy=cmd('hierarchy',[b,'runner','dump-hierarchy','--udid',u,'--format','tree']);assert b'Landmarks' in hierarchy.stdout
 if started.get('log'):shutil.copyfile(started['log'],d/'daemon.log')
 stopped=json.loads(cmd('stop',[b,'runner','stop','--json']).stdout);assert stopped['status']=='stopped' and stopped['pid']==doc['pid'];assert not session.exists();checks.append({'N3-03':'genuine starting null port -> same ready PID -> stopped','starting':second,'ready':ready,'stop':stopped});print('detached iOS lifecycle passed',flush=True)
 # Separately reach ready in foreground, then interrupt.
 (d/'ready-control.command.json').write_text(json.dumps(args));p=subprocess.Popen(args,cwd=project,stdout=(d/'ready-control.out').open('wb'),stderr=(d/'ready-control.err').open('wb'),start_new_session=True);threading.Thread(target=capture_report,args=(p,'ready-control'),daemon=True).start();deadline=time.monotonic()+120
 while time.monotonic()<deadline:
  if session.exists():
   doc=json.loads(session.read_text())
   if doc['state']=='ready':break
  assert p.poll() is None;time.sleep(.02)
 else:raise TimeoutError('ready')
 cmd('ready-control-hierarchy',[b,'runner','dump-hierarchy','--udid',u,'--format','tree']);sent=time.monotonic();os.kill(p.pid,signal.SIGINT);code=p.wait(timeout=30);record={'cliPID':p.pid,'session':doc,'exit':code,'signalToExit':time.monotonic()-sent};(d/'ready-control.result.json').write_text(json.dumps(record,indent=2));assert code==130 and not session.exists();err=(d/'ready-control.err').read_text();assert '[grantiva] received SIGINT — releasing simulator and reaping child processes' in err and 'Timed out waiting' not in err;checks.append({'steadyReadyInterrupt':record})
 cmd('processes-after',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']);print('steady ready interrupt passed',flush=True)
finally:
 if p and p.poll() is None:os.kill(p.pid,signal.SIGINT);p.wait(timeout=30)
 if session.exists():cmd('emergency-stop',[b,'runner','stop','--json'])
 (d/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
