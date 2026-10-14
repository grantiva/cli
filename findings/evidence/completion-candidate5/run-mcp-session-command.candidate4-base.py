from pathlib import Path
import hashlib,json,os,subprocess,sys,time
root=Path(__file__).resolve().parent
plans=json.loads((root/'harness/argv-bound.json').read_text())
platform,action=sys.argv[1:]
assert platform in ('ios','android') and action in ('start','stop')
assert hashlib.sha256((root/'candidate.json').read_bytes()).hexdigest()=='714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783'
binary=plans['common']['binary']
assert hashlib.sha256(Path(binary).read_bytes()).hexdigest()=='2a4e90e655b2a43234b4c1c5cac403042df17aa43e3e6bd0d011743e38fb9fb5'
args=plans['invocations']['mcp-'+platform]
cwd=args[args.index('--project')+1]
device=args[args.index('--device')+1]
argv=[binary,'runner',action]
if action=='start':
 argv+=['--platform',platform]
 argv+=['--simulator',device,'--bundle-id','com.kylebrowning.Landmarks'] if platform=='ios' else ['--device',device,'--application-id','com.kylebrowning.landmarks']
 argv+=['--detach','--json']
else:
 session=json.loads((Path(cwd)/'.grantiva/session.json').read_text())
 assert device in (session.get('udid'),session.get('device'),session.get('deviceId')) and session.get('platform')==platform
 argv+=['--json']
d=root/('04-mcp-ios' if platform=='ios' else '05-mcp-android')/('session-'+action);d.mkdir(parents=True,exist_ok=False)
env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update({k:v for k,v in plans['environment'].items() if k!='GRANTIVA_API_KEY'});env.update(JAVA_HOME='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home',ANDROID_HOME='/Users/kyle/Library/Android/sdk',ANDROID_SDK_ROOT='/Users/kyle/Library/Android/sdk');env['PATH']='/Users/kyle/Library/Android/sdk/platform-tools:'+env.get('PATH','')
(d/'start.json').write_text(json.dumps({'argv':argv,'cwd':cwd,'started':time.time(),'environment':plans['environment'],'candidateSHA256':hashlib.sha256((root/'candidate.json').read_bytes()).hexdigest()},indent=2))
with (d/'stdout.raw').open('wb') as so,(d/'stderr.raw').open('wb') as se:
 try:
  p=subprocess.run(argv,cwd=cwd,env=env,stdin=subprocess.DEVNULL,stdout=so,stderr=se,timeout=600);code=p.returncode;timed=False
 except subprocess.TimeoutExpired:code=None;timed=True
(d/'result.json').write_text(json.dumps({'exit':code,'timedOut':timed,'ended':time.time()},indent=2))
assert code==0 and not timed,(platform,action,code,timed)
print(platform,action,'completed')
