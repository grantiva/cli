from pathlib import Path
import os,json,subprocess,time,signal,sys,threading
r=Path(__file__).parent;s=json.loads((r/'state-fix4.json').read_text());i=json.loads((r/'ios-state.json').read_text());d=r/'ios-reaper-attempt2';d.mkdir();b=s['binary'];u=i['udid'];project=Path(i['project']);checks=[];p=None;look=None
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4')
def cmd(label,args,expected=0):
 p=subprocess.run(args,cwd=project,capture_output=True,timeout=100);(d/(label+'.command.json')).write_text(json.dumps(args));(d/(label+'.out')).write_bytes(p.stdout);(d/(label+'.err')).write_bytes(p.stderr);(d/(label+'.exit')).write_text(str(p.returncode));assert p.returncode==expected,(label,p.returncode,p.stderr.decode());return p
try:
 helper=project/'helper.py';args=[sys.executable,str(helper),b,u];look=subprocess.Popen(args,start_new_session=True);(d/'lookalike.json').write_text(json.dumps({'argv':args,'pid':look.pid}));report=project/'preserved-reaper-report';args=[b,'run','--no-build','--simulator',u,'--flow','slow.yaml','--report-dir',str(report)];(d/'run.command.json').write_text(json.dumps(args));p=subprocess.Popen(args,cwd=project,stdout=(d/'run.out').open('wb'),stderr=(d/'run.err').open('wb'),start_new_session=True);(d/'run.pid').write_text(str(p.pid));done=threading.Event()
 def reap():
  code=p.wait();(d/'run.exit').write_text(str(code));done.set()
 waiter=threading.Thread(target=reap,daemon=True);waiter.start();deadline=time.monotonic()+180
 while time.monotonic()<deadline:
  text=(d/'run.err').read_text()
  if 'extendedWaitUntil' in text or ('launchApp' in text and '✓' in text):break
  assert not done.is_set(),text;time.sleep(.1)
 else:raise TimeoutError('active run')
 cmd('processes-active',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']);refusal=cmd('nonforce-refusal',[b,'simulator','teardown','--udid',u,'--json'],1);assert str(p.pid) in refusal.stderr.decode() and not done.is_set()
 force=json.loads(cmd('actual-grantiva-force',[b,'simulator','teardown','--udid',u,'--force','--json']).stdout)[0];assert any(x['pid']==p.pid and x['kind']=='grantiva' for x in force['processes']),force;assert done.wait(10);assert force['reclaimed'] and not force['runnerSessionStopped'];assert look.poll() is None;assert report.exists();ps=cmd('processes-after',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']).stdout.decode()
 for item in force['processes']+force['reapedProcesses']:assert not any(line.split()[0]==str(item['pid']) for line in ps.splitlines()),item
 checks.append({'actualCLI':p.pid,'lookalike':look.pid,'nonforceRefused':True,'force':force,'callerReportPreserved':str(report)});print('actual CLI/runner reaped, lookalike survived, nonforce refused',flush=True)
finally:
 if p and p.poll() is None:os.kill(p.pid,signal.SIGINT);p.wait(timeout=30)
 if look and look.poll() is None:look.terminate();look.wait(timeout=10)
 (d/'checks.json').write_text(json.dumps(checks,indent=2))
