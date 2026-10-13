from pathlib import Path
import os,subprocess,time,json,hashlib,signal,shlex,argparse,re
ap=argparse.ArgumentParser();ap.add_argument('--binary',required=True);ap.add_argument('--source',required=True);ap.add_argument('--build-manifest',required=True);ap.add_argument('--home',required=True);ap.add_argument('--output',required=True);args=ap.parse_args()
r=Path.cwd();d=json.loads((r/'findings/evidence/fix4-4-forward/live-provision/ownership.json').read_text());o=Path(args.output);o.mkdir(parents=True,exist_ok=False)
project=Path(d['project']);home=Path(args.home);binary=Path(args.binary);adb='/Users/kyle/Library/Android/sdk/platform-tools/adb';serial=d['serial'];runner=home/'versions/1.1.28-grantiva.14+android-drivers-2/grantiva-runner';session=project/'.grantiva/session.json'
build_manifest_path=Path(args.build_manifest);runner_identity_path=r/'findings/evidence/fix4-84/joint-source-preparation/identity.json';global_sessions=Path('/tmp/grantiva-sessions')
expected_cli_source='a587581723ec2599e0247c186d27667951959d9e';expected_runner_version_line='grantiva-runner 1.1.28-grantiva.14-l83-check'
expected_interrupt_notice='\n[grantiva] received SIGINT — releasing emulator and reaping child processes\n'
env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update(GRANTIVA_RUNNER_HOME=str(home),MAESTRO_RUNNER_HOME=str(runner.parent),GRANTIVA_SESSION_ID='fix4-84',ANDROID_HOME='/Users/kyle/Library/Android/sdk',ANDROID_SDK_ROOT='/Users/kyle/Library/Android/sdk',JAVA_HOME='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home');env['PATH']='/Users/kyle/Library/Android/sdk/platform-tools:'+env['PATH']
checks=[];procs=[];controls=[];ownedports=[]
def save(n,x):(o/(n+'.json')).write_text(json.dumps(x,indent=2)+'\n')
def run(n,a,expected=0):
 a=list(map(str,a));t=time.time();p=subprocess.run(a,cwd=project,env=env,capture_output=True,timeout=180);(o/(n+'.stdout')).write_bytes(p.stdout);(o/(n+'.stderr')).write_bytes(p.stderr);save(n,{'argv':a,'cwd':str(project),'runnerHome':str(home),'maestroHome':str(runner.parent),'session':'fix4-84','apiEnvironmentUnset':True,'start':t,'end':time.time(),'exit':p.returncode});assert expected is None or p.returncode==expected,(n,p.returncode,p.stderr.decode());return p

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
 save(n,{'argv':a,'cwd':str(project),'runnerHome':str(home),'maestroHome':str(runner.parent),'session':'fix4-84','apiEnvironmentUnset':True,'start':start,'end':time.time(),'exit':code,'spawnedProcessPid':p.pid,'observedExactRunnerProcesses':list(seen.values())})
 assert code==expected,(n,code,err_path.read_text(errors='replace'))
 after=ownership_snapshot(n+'-after');before_names={x['name'] for x in before['sessions']['globalFiles']};after_names={x['name'] for x in after['sessions']['globalFiles']}
 assert not after['sessions']['projectSessionExists'],n;assert not [x for x in after['sessions']['globalFiles'] if x['mentionsDevice']],(n,after['sessions']['globalFiles']);assert not (after_names-before_names),(n,'new global sessions',sorted(after_names-before_names));assert not after['processes'],(n,after['processes'])
 for pid in set(seen)|{p.pid}:
  assert not list(global_sessions.glob(str(pid)+'*')),(n,pid);q=run(n+'-pid-'+str(pid),['/bin/ps','-p',str(pid),'-o','stat='],None);assert q.returncode!=0 or 'Z' in q.stdout.decode()
 absence(n);return code,sorted(seen)

def absence(n,pid=None):
 assert not session.exists(),n
 if pid:
  assert not list(Path('/tmp/grantiva-sessions').glob(str(pid)+'*'))
  p=run(n+'-pid',['/bin/ps','-p',str(pid),'-o','stat='],None);assert p.returncode!=0 or 'Z' in p.stdout.decode()
 for suffix in ['immediate','after1s']:
  if suffix=='after1s':time.sleep(1)
  inventory(n+'-'+suffix,True)

assert binary.exists() and runner.exists() and build_manifest_path.is_file() and runner_identity_path.is_file();assert re.fullmatch(r'[0-9a-f]{40}',args.source) and args.source==expected_cli_source
build_manifest=json.loads(build_manifest_path.read_text());runner_identity=json.loads(runner_identity_path.read_text());assert build_manifest['schemaVersion']==1;assert build_manifest['sourceSHA']==args.source;assert Path(build_manifest['sourceCheckout']).is_absolute();assert build_manifest['configuration']=='release' and build_manifest['cleanSourceBeforeAfter'] is True;assert build_manifest['build']['exit']==0 and build_manifest['build']['argv'];assert build_manifest['version']['exit']==0 and build_manifest['version']['argv']==[build_manifest['binary']['path'],'--version'];assert Path(build_manifest['binary']['path']).resolve()==binary.resolve();binary_sha=hashlib.sha256(binary.read_bytes()).hexdigest();assert build_manifest['binary']['sha256']==binary_sha
build_identity_path=build_manifest_path.parent/build_manifest['sourceBuildIdentity'];assert build_identity_path.is_file();build_identity=json.loads(build_identity_path.read_text());assert build_identity['source']==args.source and build_identity['sourceAfter']==args.source and build_identity['statusAfter']=='' and build_identity['exit']==0;assert Path(build_identity['binary']).resolve()==binary.resolve() and build_identity['binarySHA256']==binary_sha
source_checkout=Path(build_manifest['sourceCheckout']);assert source_checkout.is_dir();source_head=run('source-head',['/usr/bin/git','-C',source_checkout,'rev-parse','HEAD']).stdout.decode().strip();assert source_head==args.source;source_status=run('source-status',['/usr/bin/git','-C',source_checkout,'status','--porcelain=v1']).stdout.decode();assert source_status==''
cli_version=run('cli-version',[binary,'--version']).stdout.decode().strip();assert cli_version==build_manifest['version']['stdout'].strip()
runner_version_output=run('runner-native-version',[runner,'--version']).stdout.decode();runner_version_lines=runner_version_output.splitlines();assert runner_version_lines and runner_version_lines[0]==expected_runner_version_line,runner_version_output
assert run('avd-identity',[adb,'-s',serial,'emu','avd','name']).stdout.decode().splitlines()[0]==d['avd'];assert not session.exists();assert serial not in run('baseline',[adb,'forward','--list']).stdout.decode()
save('candidate',{'cliSource':args.source,'binary':str(binary),'binarySHA256':binary_sha,'cliVersion':cli_version,'sourceBuildManifestPath':str(build_manifest_path),'sourceBuildManifest':build_manifest,'sourceBuildIdentityPath':str(build_identity_path),'sourceBuildIdentity':build_identity,'sourceCheckoutValidation':{'path':str(source_checkout),'head':source_head,'porcelainStatus':source_status},'runnerSource':'6b3c206a5c2590c8384c5a01077a9bf932c83be4','runnerSHA256':hashlib.sha256(runner.read_bytes()).hexdigest(),'runnerNativeVersionOutput':runner_version_output,'runnerNativeVersionLines':runner_version_lines,'runnerPreparationIdentityPath':str(runner_identity_path),'runnerPreparationIdentity':runner_identity,'ownership':d,'qualification':'Joint source repair validation with exact clean release-build manifest and explicitly replaced source-built L83 check runner in isolated clone; not a packaged .15 candidate.'})
assert hashlib.sha256(runner.read_bytes()).hexdigest()=='cb41a3053625e73ff38fdd6c876f7b67274fb6e5a9317681a1fd4ee31146db8c'
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
  absence(mode,pid);checks.append({'case':mode,'exit':code,'controlsPreserved':True,'ownedForwardsAndSessionAndPIDAbsent':True})
 code,seen=run_owned_case('absent-app',[binary,'runner','start','--platform','android','--device',serial,'--application-id','com.grantiva.task8.absent','--detach','--json'],1);checks.append({'case':'absent-app','exit':code,'controlsPreserved':True,'ownedForwardsAndProjectGlobalSessionsAndRunnerPIDsAbsent':True,'observedRunnerPids':seen})
 # Copy stock input into this attempt so screenshot outputs cannot overwrite historical evidence.
 import shutil
 inp=o/'inputs';shutil.copytree(r/'findings/evidence/round4-smoke/inputs',inp)
 code,seen=run_owned_case('healthy',[runner,'--platform','android','--device',serial,'--no-ansi','--no-app-install','test','--output',o/'healthy-report','--flatten',inp/'healthy-stock.yaml'],0);checks.append({'case':'healthy-stock','exit':code,'controlsPreserved':True,'ownedForwardsAndProjectGlobalSessionsAndRunnerPIDsAbsent':True,'observedRunnerPids':seen})
 save('acceptance',{'passed':True,'scope':'Joint source repair validation, packaged candidate pending','checks':checks});print(json.dumps({'passed':True,'checks':len(checks)}))
finally:
 for p in procs:
  if p.poll() is None:os.kill(p.pid,signal.SIGINT);p.wait(timeout=45)
 f=run('cleanup-before',[adb,'forward','--list']).stdout.decode()
 for row in controls:
  if row in f:run('cleanup-control-'+row.split()[1].replace(':','-'),[adb,'-s',serial,'forward','--remove',row.split()[1]])
 for port in ownedports:
  if f'{serial} tcp:{port} ' in f:run('cleanup-owned-'+str(port),[adb,'-s',serial,'forward','--remove','tcp:'+str(port)])
 run('cleanup-after',[adb,'forward','--list'])
