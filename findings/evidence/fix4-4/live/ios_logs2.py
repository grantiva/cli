from pathlib import Path
import os,json,subprocess,time,signal,re
r=Path(__file__).parent;s=json.loads((r/'state-fix4.json').read_text());main=json.loads((r/'ios-state.json').read_text());control=json.loads((r/'ios-control-state.json').read_text());d=r/'ios-logs-attempt2';d.mkdir();b=s['binary'];checks=[]
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4')
for device in [main,control]:
 project=Path(device['project']);(project/'success.yaml').write_text('appId: com.kylebrowning.Landmarks\n---\n- launchApp\n- assertVisible: Landmarks\n')
 (project/'failure.yaml').write_text('appId: com.kylebrowning.Landmarks\n---\n- launchApp\n- assertVisible: fix44-deliberately-absent\n')
 (project/'slow.yaml').write_text('appId: com.kylebrowning.Landmarks\n---\n- launchApp\n- extendedWaitUntil:\n    visible: fix44-deliberately-absent\n    timeout: 300000\n')
def snapshot(label):
 data=subprocess.check_output(['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command='],text=True);(d/(label+'.ps')).write_text(data);return data

def begin(label,device,flow,flags=[]):
 args=[b,'run','--no-build','--simulator',device['udid'],'--flow',flow,'--logs','--logs-predicate','process == "Landmarks"']+flags;(d/(label+'.command.json')).write_text(json.dumps({'argv':args,'cwd':device['project']}));p=subprocess.Popen(args,cwd=device['project'],stdout=(d/(label+'.out')).open('wb'),stderr=(d/(label+'.err')).open('wb'),start_new_session=True);(d/(label+'.pid')).write_text(str(p.pid));return p

def observe(label,p,device):
 deadline=time.monotonic()+180
 while time.monotonic()<deadline:
  ps=subprocess.check_output(['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command='],text=True)
  wrappers=[x for x in ps.splitlines() if 'simctl spawn '+device['udid']+' log stream' in x and 'grantiva-log-' in x]
  if wrappers:
   marker=re.search(r'grantiva-log-[A-F0-9-]+',wrappers[0]).group();children=[x for x in ps.splitlines() if marker in x and x.split(maxsplit=3)[3].startswith('log stream ')]
   if children:
    record={'marker':marker,'wrapper':int(wrappers[0].split()[0]),'child':int(children[0].split()[0]),'cli':p.pid,'device':device['udid']};(d/(label+'.ownership.json')).write_text(json.dumps(record,indent=2));(d/(label+'-active.ps')).write_text(ps);return record
  assert p.poll() is None,(label,'exited before owned child observed',(d/(label+'.err')).read_text());time.sleep(.025)
 raise TimeoutError('owned log child '+label)
ctrl=None;p=None
try:
 ready=Path(control['project'])/'control-ready2.json';ctrl=begin('control',control,'success.yaml',['--keep-alive','--ready-file',str(ready),'--verbose']);owner=observe('control',ctrl,control);deadline=time.monotonic()+240
 while not ready.exists() and time.monotonic()<deadline:assert ctrl.poll() is None;time.sleep(.1)
 assert ready.exists() and json.loads(ready.read_text())['status']=='passed';(d/'control-ready2.json').write_bytes(ready.read_bytes());print('control keep-alive and log active',flush=True)
 for label,flow,verbose,interrupt,wrapperfirst in [('interrupt-plain-repeat','slow.yaml',False,True,False),('interrupt-verbose-repeat','slow.yaml',True,True,False),('interrupt-wrapper-first','slow.yaml',True,True,True)]:
  p=begin(label,main,flow,['--verbose'] if verbose else []);owned=observe(label,p,main)
  if interrupt:
   if wrapperfirst:
    os.kill(owned['child'],signal.SIGSTOP);os.kill(owned['wrapper'],signal.SIGKILL);time.sleep(.05);proof=snapshot(label+'-wrapper-gone-child-held');assert not any(x.split()[0]==str(owned['wrapper']) for x in proof.splitlines());owned['childSurvivedWrapperExit']=any(x.split()[0]==str(owned['child']) for x in proof.splitlines());owned['intervention']='exact marked child SIGSTOP; wrapper SIGKILL; observe child; CLI SIGINT'
   os.kill(p.pid,signal.SIGINT)
  code=p.wait(timeout=180);returned=time.time();inventories=[snapshot(label+'-after-'+str(n)) for n in range(3)];(d/(label+'.result.json')).write_text(json.dumps({'exit':code,'returnedEpoch':returned,'owned':owned},indent=2))
  assert code==(130 if interrupt else 1 if flow=='failure.yaml' else 0),(label,code,(d/(label+'.err')).read_text())
  for ps in inventories:
   assert owned['marker'] not in ps,(label,'owned log survives return')
   assert owner['marker'] in ps and ctrl.poll() is None,(label,'control run affected')
  err=(d/(label+'.err')).read_text();assert 'could not confirm log-stream cleanup' not in err and 'predicate'+' parse' not in err
  terminals=[line for line in err.splitlines() if 'simctl spawn '+main['udid']+' log stream' in line and ('stopped by ' in line or 'exit ' in line)]
  if verbose:assert len(terminals)==1,(label,terminals)
  else:assert '[debug]' not in err
  checks.append({'case':label,'exit':code,'owned':owned,'immediateInventories':3,'controlSurvived':True,'terminalDiagnostics':terminals});(d/'checks.json').write_text(json.dumps(checks,indent=2));print(label,'passed',code,flush=True)
 os.kill(ctrl.pid,signal.SIGINT);code=ctrl.wait(timeout=30);ps=snapshot('control-after');assert owner['marker'] not in ps;assert code==0,code;(d/'control.exit').write_text(str(code));print('control released cleanly',flush=True)
finally:
 for child in [p,ctrl]:
  if child and child.poll() is None:os.kill(child.pid,signal.SIGINT);child.wait(timeout=30)
 (d/'checks.json').write_text(json.dumps(checks,indent=2))
