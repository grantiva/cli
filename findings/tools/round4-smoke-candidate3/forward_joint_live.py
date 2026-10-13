from pathlib import Path
import os,subprocess,time,json,hashlib,signal,shlex,argparse,re
from candidate_identity import validate
ap=argparse.ArgumentParser();ap.add_argument('--candidate',required=True);ap.add_argument('--ownership',required=True);ap.add_argument('--source-root',required=True);ap.add_argument('--binary',required=True);ap.add_argument('--bundle',required=True);ap.add_argument('--packaged-runner',required=True);ap.add_argument('--home',required=True);ap.add_argument('--project',required=True);ap.add_argument('--output',required=True);args=ap.parse_args()
r=Path.cwd();candidate_path=Path(args.candidate).resolve();ownership_path=Path(args.ownership).resolve();candidate=json.loads(candidate_path.read_text());ownership=json.loads(ownership_path.read_text());android=ownership['devices']['android'];o=Path(args.output);o.mkdir(parents=True,exist_ok=False)
project=Path(args.project).resolve();home=Path(args.home).resolve();binary=Path(args.binary).resolve();bundle=Path(args.bundle).resolve();packaged_runner=Path(args.packaged_runner).resolve();adb='/Users/kyle/Library/Android/sdk/platform-tools/adb';serial=android['id'];runner=Path(candidate['runner']['installed']['path']).resolve();session=project/'.grantiva/session.json';global_sessions=Path('/tmp/grantiva-sessions')
expected_interrupt_notice='\n[grantiva] received SIGINT — releasing emulator and reaping child processes\n'
env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update(GRANTIVA_RUNNER_HOME=str(home),MAESTRO_RUNNER_HOME=str(runner.parent),GRANTIVA_SESSION_ID='fix4-8-c3',ANDROID_HOME='/Users/kyle/Library/Android/sdk',ANDROID_SDK_ROOT='/Users/kyle/Library/Android/sdk',JAVA_HOME='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home');env['PATH']='/Users/kyle/Library/Android/sdk/platform-tools:'+env['PATH']
checks=[];procs=[];controls=[];ownedports=[]
def save(n,x):(o/(n+'.json')).write_text(json.dumps(x,indent=2)+'\n')
def run(n,a,expected=0):
 a=list(map(str,a));t=time.time();p=subprocess.run(a,cwd=project,env=env,capture_output=True,timeout=180);(o/(n+'.stdout')).write_bytes(p.stdout);(o/(n+'.stderr')).write_bytes(p.stderr);save(n,{'argv':a,'cwd':str(project),'runnerHome':str(home),'maestroHome':str(runner.parent),'session':'fix4-8-c3','apiEnvironmentUnset':True,'start':t,'end':time.time(),'exit':p.returncode});assert expected is None or p.returncode==expected,(n,p.returncode,p.stderr.decode());return p

def inventory(n,only_controls=False):
 f=run(n,[adb,'forward','--list']).stdout.decode();rows=[x for x in f.splitlines() if x.startswith(serial+' ')]
 assert all(x in rows for x in controls),(n,rows,controls)
 if only_controls:assert set(rows)==set(controls),(n,rows,controls)
 return rows

def exact_runner_processes(n=None):
 p=subprocess.run(['/bin/ps','-axo','pid=,ppid=,command='],capture_output=True,timeout=30)
 assert p.returncode==0,p.stderr.decode()
 rows=[]
 for line in p.stdout.decode().splitlines():
  fields=line.strip().split(None,2)
  if len(fields)!=3:continue
  try:parts=shlex.split(fields[2])
  except ValueError:continue
  if str(runner) in parts and serial in parts:rows.append({'pid':int(fields[0]),'ppid':int(fields[1]),'command':fields[2]})
 if n:
  (o/(n+'.ps')).write_bytes(p.stdout);save(n,{'exactExecutable':str(runner),'device':serial,'matches':rows})
 return rows

def session_inventory(n):
 files=[]
 if global_sessions.exists():
  for path in sorted(global_sessions.iterdir()):
   if not path.is_file():continue
   raw=path.read_bytes();files.append({'name':path.name,'sha256':hashlib.sha256(raw).hexdigest(),'size':len(raw),'mentionsDevice':serial.encode() in raw})
 state={'projectSessionExists':session.exists(),'globalDirectory':str(global_sessions),'globalFiles':files}
 if session.exists():
  raw=session.read_bytes();state['projectSessionSHA256']=hashlib.sha256(raw).hexdigest();state['projectSession']=json.loads(raw)
 save(n,state);return state

def ownership_snapshot(n):
 return {'sessions':session_inventory(n+'-sessions'),'processes':exact_runner_processes(n+'-processes')}

def run_owned_case(n,a,expected):
 before=ownership_snapshot(n+'-before');assert not before['sessions']['projectSessionExists'];assert not [x for x in before['sessions']['globalFiles'] if x['mentionsDevice']],(n,before['sessions']['globalFiles']);assert not before['processes'],(n,before['processes'])
 a=list(map(str,a));out_path=o/(n+'.stdout');err_path=o/(n+'.stderr');start=time.time();seen={}
 with out_path.open('wb') as out,err_path.open('wb') as err:
  p=subprocess.Popen(a,cwd=project,env=env,stdout=out,stderr=err,start_new_session=True);procs.append(p)
  deadline=time.time()+180
  while p.poll() is None:
   assert time.time()<deadline,(n,'timeout',p.pid)
   for row in exact_runner_processes():seen[row['pid']]=dict(row,observedAt=time.time())
   time.sleep(.05)
  code=p.returncode
 save(n,{'argv':a,'cwd':str(project),'runnerHome':str(home),'maestroHome':str(runner.parent),'session':'fix4-8-c3','apiEnvironmentUnset':True,'start':start,'end':time.time(),'exit':code,'spawnedProcessPid':p.pid,'observedExactRunnerProcesses':list(seen.values())})
 assert code==expected,(n,code,err_path.read_text(errors='replace'))
 after=ownership_snapshot(n+'-after');before_names={x['name'] for x in before['sessions']['globalFiles']};after_names={x['name'] for x in after['sessions']['globalFiles']}
 assert not after['sessions']['projectSessionExists'],n;assert not [x for x in after['sessions']['globalFiles'] if x['mentionsDevice']],(n,after['sessions']['globalFiles']);assert not (after_names-before_names),(n,'new global sessions',sorted(after_names-before_names));assert not after['processes'],(n,after['processes'])
 known_pids=set(seen)|{p.pid}
 for pid in known_pids:
  assert not list(global_sessions.glob(str(pid)+'*')),(n,pid);q=run(n+'-pid-'+str(pid),['/bin/ps','-p',str(pid),'-o','stat='],None);assert q.returncode!=0 or 'Z' in q.stdout.decode()
 absence(n,known_pids);return code,sorted(seen)

def absence(n,pids=()):
 for suffix in ['immediate','after1s']:
  if suffix=='after1s':time.sleep(1)
  state=ownership_snapshot(n+'-'+suffix)
  assert not state['sessions']['projectSessionExists'],n
  assert not [x for x in state['sessions']['globalFiles'] if x['mentionsDevice']],(n,state['sessions']['globalFiles'])
  assert not state['processes'],(n,state['processes'])
  for pid in pids:
   assert not list(global_sessions.glob(str(pid)+'*'))
   p=run(n+'-'+suffix+'-pid',['/bin/ps','-p',str(pid),'-o','stat='],None);assert p.returncode!=0 or 'Z' in p.stdout.decode()
  inventory(n+'-'+suffix,True)

assert project.is_dir() and candidate_path.is_file() and ownership_path.is_file()
identity=validate(candidate_path,ownership_path,source_root=args.source_root,binary=binary,bundle=bundle,runner=packaged_runner,runner_home=home,platform='android',device=serial,android_avd=android['avd'])
source_checkout=Path(args.source_root).resolve();source_head=run('source-head',['/usr/bin/git','-C',source_checkout,'rev-parse','HEAD']).stdout.decode().strip();assert source_head==candidate['cli']['mergedSHA'];source_status=run('source-status',['/usr/bin/git','-C',source_checkout,'status','--porcelain=v1']).stdout.decode();assert source_status==''
cli_version=run('cli-version',[binary,'--version']).stdout.decode().strip();assert cli_version==candidate['cli']['binary']['version']
runner_version_output=run('runner-native-version',[runner,'--version']).stdout.decode();assert runner_version_output.strip()==candidate['runner']['installed']['version'].strip(),runner_version_output
assert run('avd-identity',[adb,'-s',serial,'emu','avd','name']).stdout.decode().splitlines()[0]==android['avd'];assert not session.exists()
baseline_output=run('baseline',[adb,'forward','--list']).stdout.decode();baseline_rows=[x for x in baseline_output.splitlines() if x.startswith(serial+' ')];assert not baseline_rows,baseline_rows
save('candidate',{'validatedIdentity':identity,'candidateManifest':str(candidate_path),'ownershipManifest':str(ownership_path),'cliSource':candidate['cli']['mergedSHA'],'binary':str(binary),'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),'bundle':str(bundle),'bundleManifestSHA256':candidate['cli']['bundle']['manifestSHA256'],'cliVersion':cli_version,'sourceCheckoutValidation':{'path':str(source_checkout),'head':source_head,'porcelainStatus':source_status},'runnerSource':candidate['runner']['sourceSHA'],'packagedRunner':str(packaged_runner),'packagedRunnerSHA256':hashlib.sha256(packaged_runner.read_bytes()).hexdigest(),'installedRunner':str(runner),'installedRunnerSHA256':hashlib.sha256(runner.read_bytes()).hexdigest(),'runnerNativeVersionOutput':runner_version_output,'runnerInstallStamp':candidate['runner']['installed']['installStamp'],'ownership':ownership,'qualification':'Final packaged candidate 2 validated by candidate_identity.validate before joint forward cleanup cases.'})
try:
 run('control6790-create',[adb,'-s',serial,'forward','--no-rebind','tcp:6790','tcp:16790']);controls.append(f'{serial} tcp:6790 tcp:16790')
 port=run('allocated-control-create',[adb,'-s',serial,'forward','tcp:0','tcp:16791']).stdout.decode().strip();assert port.isdigit();controls.append(f'{serial} tcp:{port} tcp:16791');inventory('controls-before',True)
 for mode in ['interrupt','normal-stop']:
  inventory(mode+'-before',True)
  a=[str(binary),'runner','start','--platform','android','--device',serial,'--application-id','com.kylebrowning.landmarks'];out=(o/(mode+'.stdout')).open('wb');err=(o/(mode+'.stderr')).open('wb');p=subprocess.Popen(a,cwd=project,env=env,stdout=out,stderr=err,start_new_session=True);procs.append(p);save(mode+'-command',{'argv':a,'pid':p.pid,'cwd':str(project),'start':time.time()})
  try:
   ready=None
   for _ in range(1200):
    if session.exists():
     try:q=json.loads(session.read_text())
     except json.JSONDecodeError:q={}
     if q.get('state')=='ready':ready=q;break
    assert p.poll() is None,'foreground exited before ready';time.sleep(.1)
   assert ready;save(mode+'-ready',ready);ownedports.append(ready['port']);pid=ready['pid'];assert ready['udid']==serial
   argv=run(mode+'-runner-identity',['/bin/ps','-ww','-p',str(pid),'-o','command=']).stdout.decode();parts=shlex.split(argv);assert serial in parts and str(runner) in parts
   f=inventory(mode+'-ready-forwards');assert f'{serial} tcp:{ready["port"]} tcp:6790' in f
   run(mode+'-hierarchy',[binary,'runner','dump-hierarchy','--udid',serial,'--format','tree'])
   if mode=='interrupt':os.kill(p.pid,signal.SIGINT)
   else:run(mode+'-request',[binary,'runner','stop','--json'])
   code=p.wait(timeout=45);save(mode+'-exit',{'exit':code,'end':time.time()});assert code==(130 if mode=='interrupt' else 0)
  finally:out.close();err.close()
  if mode=='interrupt':assert expected_interrupt_notice in (o/(mode+'.stderr')).read_text(errors='replace')
  absence(mode,{pid});checks.append({'case':mode,'exit':code,'controlsPreserved':True,'ownedForwardsAndSessionAndPIDAbsent':True})
 code,seen=run_owned_case('absent-app',[binary,'runner','start','--platform','android','--device',serial,'--application-id','com.grantiva.task8.absent','--detach','--json'],1);checks.append({'case':'absent-app','exit':code,'controlsPreserved':True,'ownedForwardsAndProjectGlobalSessionsAndRunnerPIDsAbsent':True,'observedRunnerPids':seen})
 # Copy stock input into this attempt so screenshot outputs cannot overwrite historical evidence.
 import shutil
 inp=o/'inputs';shutil.copytree(r/'findings/evidence/round4-smoke/inputs',inp)
 code,seen=run_owned_case('healthy',[runner,'--platform','android','--device',serial,'--no-ansi','--no-app-install','test','--output',o/'healthy-report','--flatten',inp/'healthy-stock.yaml'],0);checks.append({'case':'healthy-stock','exit':code,'controlsPreserved':True,'ownedForwardsAndProjectGlobalSessionsAndRunnerPIDsAbsent':True,'observedRunnerPids':seen})
 save('acceptance',{'passed':True,'scope':'Final packaged candidate 2 joint forward cleanup','checks':checks});print(json.dumps({'passed':True,'checks':len(checks)}))
finally:
 for p in procs:
  if p.poll() is None:os.kill(p.pid,signal.SIGINT);p.wait(timeout=45)
 f=run('cleanup-before',[adb,'forward','--list']).stdout.decode();cleanup_before_rows=[x for x in f.splitlines() if x.startswith(serial+' ')]
 if len(controls)==2:assert set(cleanup_before_rows)==set(controls),(cleanup_before_rows,controls)
 for row in controls:
  if row in f:run('cleanup-control-'+row.split()[1].replace(':','-'),[adb,'-s',serial,'forward','--remove',row.split()[1]])
 for port in ownedports:
  if f'{serial} tcp:{port} ' in f:run('cleanup-owned-'+str(port),[adb,'-s',serial,'forward','--remove','tcp:'+str(port)])
 cleanup_after=run('cleanup-after',[adb,'forward','--list']).stdout.decode();cleanup_after_rows=[x for x in cleanup_after.splitlines() if x.startswith(serial+' ')];assert cleanup_after_rows==baseline_rows,(cleanup_after_rows,baseline_rows)
