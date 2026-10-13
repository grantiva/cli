"""Invoke one reviewed smoke helper with the frozen candidate's exact paths."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,time
p=argparse.ArgumentParser();p.add_argument('phase',choices=['android','lifecycle','joint','mcp-ios','mcp-android','force']);p.add_argument('--output');a=p.parse_args()
r=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression');e=r/'findings/evidence/round4-smoke-candidate2';h=r/'findings/tools/round4-smoke-candidate2';c=json.loads((e/'candidate.json').read_text());state=json.loads((e/'initial-state.json').read_text());own=json.loads((e/'provision/ownership.json').read_text());s=Path(state['scratch']);b=c['cli']['binary']['path'];bundle=c['cli']['bundle']['path'];runner=c['runner']['packaged']['path'];home=c['runner']['runnerHome'];source=c['cli']['repoPath'];ios=own['devices']['ios']['id'];android=own['devices']['android']['id'];avd=own['devices']['android']['avd'];adb='/Users/kyle/Library/Android/sdk/platform-tools/adb'
env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update(GRANTIVA_RUNNER_HOME=home,MAESTRO_RUNNER_HOME=home,GRANTIVA_SESSION_ID='fix4-8',ANDROID_HOME='/Users/kyle/Library/Android/sdk',ANDROID_SDK_ROOT='/Users/kyle/Library/Android/sdk',JAVA_HOME='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home');env['PATH']=str(Path(adb).parent)+':'+env['PATH']
identity=['--candidate-manifest',e/'candidate.json','--ownership-manifest',e/'provision/ownership.json','--source-root',source,'--binary',b,'--bundle',bundle,'--runner',runner,'--runner-home',home]
names={'android':'02-runner-android','lifecycle':'03-lifecycle','joint':'03b-joint-forward','mcp-ios':'04-mcp-ios','mcp-android':'05-mcp-android','force':'07-final-force-teardown'};o=Path(a.output).resolve() if a.output else e/names[a.phase];o.mkdir(parents=True,exist_ok=False)
def run(label,argv,cwd=r,timeout=1800):
 d=o/label;d.mkdir(exist_ok=False);argv=list(map(str,argv));m={'argv':argv,'cwd':str(cwd),'runnerHome':home,'maestroRunnerHome':home,'session':'fix4-8','apiEnvironmentUnset':True,'startEpoch':time.time(),'candidateManifestSHA256':hashlib.sha256((e/'candidate.json').read_bytes()).hexdigest()};(d/'start.json').write_text(json.dumps(m,indent=2)+'\n')
 with (d/'stdout.log').open('wb') as so,(d/'stderr.log').open('wb') as se:q=subprocess.run(argv,cwd=cwd,env=env,stdout=so,stderr=se,timeout=timeout)
 m.update(exit=q.returncode,endEpoch=time.time());(d/'result.json').write_text(json.dumps(m,indent=2)+'\n');assert q.returncode==0,(label,q.returncode);return (d/'stdout.log').read_text()
if a.phase=='android':
 helper=h/'android_runner_smoke.py';source_inputs=e/'inputs';fixture_root=o/'inputs';fixture_root.mkdir();fixture_manifest=json.loads((source_inputs/'fixture-manifest.json').read_text());copied=[]
 for row in fixture_manifest:
  source_fixture=Path(row['path']).resolve();assert source_fixture.is_relative_to(source_inputs.resolve()) and source_fixture.suffix.lower()!='.png';assert hashlib.sha256(source_fixture.read_bytes()).hexdigest()==row['sha256'];relative=source_fixture.relative_to(source_inputs.resolve());destination=fixture_root/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source_fixture,destination);assert hashlib.sha256(destination.read_bytes()).hexdigest()==row['sha256'];copied.append({'source':str(source_fixture),'destination':str(destination),'sha256':row['sha256']})
 (o/'fixture-copy.json').write_text(json.dumps(copied,indent=2)+'\n');assert len(copied)==len(fixture_manifest) and not list(fixture_root.rglob('*.png'))
 argv=['python3',helper,*identity,'--project',s/'android-smoke-project','--serial',android,'--avd',avd,'--apk',c['demo']['androidAPK']['path'],'--adb',adb,'--uia2-sampler',r/'findings/evidence/fix4-2/uia2-source-snapshot-v2.py','--movement-analyzer',r/'findings/evidence/fix4-2/analyze-l51-movement.py','--runner-inputs',fixture_root/'runner-inputs','--optional-inputs',fixture_root/'optional-inputs','--crash-flow',fixture_root/'crash.yaml','--healthy-flow',fixture_root/'healthy-stock.yaml','--cycle-project',s/'cycle-project','--cycle-flow','subdirectory/a.yaml','--evidence',o/'helper']
elif a.phase in ['lifecycle','force']:
 helper=h/'lifecycle_smoke.py';args=identity.copy();args[args.index('--source-root')]='--source';argv=['python3',helper,*args,'--project',s/'lifecycle-project','--session-id','fix4-8','--ios-udid',ios,'--android-serial',android,'--android-avd',avd,'--ios-app',c['demo']['iosApp']['path'],'--output',o/'helper']
 if a.phase=='force':argv+=['--phase','force-teardown','--allow-force-reclaim-owned-ios']
elif a.phase=='joint':
 helper=h/'forward_joint_live.py';argv=['python3',helper,'--candidate',e/'candidate.json','--ownership',e/'provision/ownership.json','--source-root',source,'--binary',b,'--bundle',bundle,'--packaged-runner',runner,'--home',home,'--project',s/'ready-forward-project','--output',o/'helper']
else:
 platform=a.phase.removeprefix('mcp-');device=ios if platform=='ios' else android;project=s/(a.phase+'-project');helper=h/'mcp_smoke.py';argv=['python3',helper,*identity,'--platform',platform,'--device',device,'--project',project,'--no-session-project',s/(a.phase+'-no-session'),'--large-seed',e/'inputs'/(platform+'-large-hierarchy-seed.json'),'--evidence',o/'helper','--pairs','10']
 if platform=='ios':argv+=['--ios-simctl','/usr/bin/xcrun','--ios-app-id','com.kylebrowning.Landmarks'];start=[b,'runner','start','--platform','ios','--simulator',device,'--bundle-id','com.kylebrowning.Landmarks','--detach','--json']
 else:argv+=['--android-avd',avd];start=[b,'runner','start','--platform','android','--device',device,'--application-id','com.kylebrowning.landmarks','--detach','--json']
 preflight=['python3',h/'candidate_identity.py',*identity,'--platform',platform,'--device',device]
 if platform=='android':preflight+=['--android-avd',avd]
 assert not (project/'.grantiva/session.json').exists()
 try:
  run('preflight',preflight);run('start',start,project,240);shutil.copy2(helper,o/'executed-helper.py');run('invocation',argv)
 finally:
  session=project/'.grantiva/session.json'
  if session.exists():
   doc=json.loads(session.read_text());assert doc.get('udid')==device and doc.get('platform')==platform
   run('stop',[b,'runner','stop','--json'],project,120)
  assert not session.exists()
 print('Phase passed:',a.phase);raise SystemExit(0)
shutil.copy2(helper,o/'executed-helper.py');run('invocation',argv);print('Phase passed:',a.phase)
