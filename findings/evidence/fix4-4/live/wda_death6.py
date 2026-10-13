from pathlib import Path
import os,json,subprocess,time,signal,threading,shlex,shutil
r=Path(__file__).parent/'wda-death-fix6';s=json.loads((r/'state.json').read_text());i=s['ios'];u=i['udid'];project=Path(i['project']);session=project/'.grantiva/session.json';b=s['binary'];os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4');args=[b,'runner','start','--simulator',u,'--bundle-id','com.kylebrowning.Landmarks','--verbose'];(r/'start.command.json').write_text(json.dumps(args));p=subprocess.Popen(args,cwd=project,stdout=(r/'start.out').open('wb'),stderr=(r/'start.err').open('wb'),start_new_session=True);(r/'cli.pid').write_text(str(p.pid));started=time.monotonic();killed=[];seen=set();done=threading.Event();result={}
def reap():
 result['exit']=p.wait();result['exitEpoch']=time.time();done.set()
threading.Thread(target=reap,daemon=True).start()
try:
 while time.monotonic()-started<180 and not done.is_set():
  ps=subprocess.check_output(['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command='],text=True)
  if session.exists():
   try:
    currentdoc=json.loads(session.read_text()); runnerpid=currentdoc['pid']
    argv=shlex.split(subprocess.check_output(['/bin/ps','-ww','-p',str(runnerpid),'-o','command='],text=True))
    if '--output' in argv:
     report=Path(argv[argv.index('--output')+1]); (r/'runner-argv.json').write_text(json.dumps(argv))
     if report.exists():shutil.copytree(report,r/'generated-report',dirs_exist_ok=True)
     flow=Path(argv[-1])
     if flow.exists():shutil.copy2(flow,r/'generated-flow.yaml')
    (r/'last-session.json').write_text(json.dumps(currentdoc))
    assert currentdoc['state']!='ready','Failed launch was published ready'
   except (FileNotFoundError,json.JSONDecodeError,subprocess.CalledProcessError):pass
  for line in ps.splitlines():
   fields=line.split(maxsplit=3)
   if len(fields)<4:continue
   pid=int(fields[0]);command=fields[3]
   if pid not in seen and '/CoreSimulator/Devices/'+u+'/' in command and command.endswith('/WebDriverAgentRunner-Runner.app/WebDriverAgentRunner-Runner'):
    # Verify exact command identity immediately before targeting this observed child.
    current=subprocess.check_output(['/bin/ps','-ww','-p',str(pid),'-o','command='],text=True).strip()
    if current!=command:continue
    seen.add(pid);doc=json.loads(session.read_text()) if session.exists() else None;record={'pid':pid,'ppid':int(fields[1]),'processGroup':int(fields[2]),'command':command,'sessionAtSignal':doc,'signal':'SIGKILL','timeAfterStart':time.monotonic()-started,'signalEpoch':time.time()};(r/('wda-'+str(pid)+'-active.ps')).write_text(ps);(r/('wda-'+str(pid)+'.json')).write_text(json.dumps(record,indent=2));os.kill(pid,signal.SIGKILL);killed.append(record);print('killed exact owned WDA',pid,'state',doc.get('state') if doc else None,flush=True)
  time.sleep(.01)
 assert done.is_set(),'foreground start did not finish in bounded control'
 result.update(duration=time.monotonic()-started,cliPID=p.pid,actualWDADeaths=killed,sessionAbsent=not session.exists());(r/'result.json').write_text(json.dumps(result,indent=2));err=(r/'start.err').read_text();assert killed,'no actual WDA child observed';assert result['exit']==1 and 'Error:' in err and 'received SIGINT' not in err,(result,err[-3000:]);assert not session.exists();ps=subprocess.check_output(['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command='],text=True);(r/'processes-after.out').write_text(ps)
 for item in killed:assert not any(line.split()[0]==str(item['pid']) for line in ps.splitlines())
 runnerpids={item['sessionAtSignal']['pid'] for item in killed if item['sessionAtSignal']};assert not any(line.split()[0] in {str(x) for x in runnerpids} for line in ps.splitlines());left=[str(path) for pid in runnerpids for path in Path('/tmp/grantiva-sessions').glob(str(pid)+'*')];(r/'shared-after.json').write_text(json.dumps(left));assert not left,left;print('actual WDA death control passed',result['exit'],result['duration'],flush=True)
finally:
 if not done.is_set():
  (r/'emergency-cli-signal.json').write_text(json.dumps({'pid':p.pid,'signal':'SIGINT','reason':'failed bounded acceptance cleanup'}));os.kill(p.pid,signal.SIGINT);done.wait(35)
