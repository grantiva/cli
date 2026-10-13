from pathlib import Path
import os,json,subprocess,time,urllib.request,signal
r=Path(__file__).parent;s=json.loads((r/'state-fix2.json').read_text());a=s['android'];project=Path(a['project']);binary=s['binary'];serial=a['serial'];adb=a['adb'];d=r/'android-controls-attempt1';d.mkdir();checks=[]
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],MAESTRO_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-4',ANDROID_HOME='/Users/kyle/Library/Android/sdk')
def command(label,args,expected=0,timeout=120,cwd=project):
 t=time.monotonic();(d/(label+'.command.json')).write_text(json.dumps({'argv':args,'cwd':str(cwd)})+'\n');p=subprocess.run(args,cwd=cwd,capture_output=True,timeout=timeout);duration=time.monotonic()-t
 (d/(label+'.out')).write_bytes(p.stdout);(d/(label+'.err')).write_bytes(p.stderr);(d/(label+'.result.json')).write_text(json.dumps({'exit':p.returncode,'duration':duration})+'\n')
 if expected is not None:assert p.returncode==expected,(label,p.returncode,p.stderr.decode())
 return p,duration
start=[binary,'runner','start','--platform','android','--device',serial,'--application-id','com.kylebrowning.landmarks','--detach','--json'];session=project/'.grantiva/session.json'
def sessions(port,label):
 url=f'http://127.0.0.1:{port}/wd/hub/sessions';data=urllib.request.urlopen(url,timeout=5).read();(d/(label+'.json')).write_bytes(data);return json.loads(data)['value'][0]['id']
try:
 before,_=command('forwards-before',[adb,'-s',serial,'forward','--list'])
 for verb in [['run','--no-build'],['runner','start']]:
  for flag in ['--device','--simulator','--emulator']:
   for value in ['', '   ']:
    label='empty-'+ '-'.join(verb[:2])+'-'+flag[2:]+'-'+str(len(value));p,_=command(label,[binary]+verb+[flag,value],expected=64);assert b'must not be empty' in p.stderr or b'empty' in p.stderr,p.stderr
 p,_=command('unknown-serial',[binary,'run','--serial','anything'],expected=64);assert b'Unknown option' in p.stderr
 after,_=command('forwards-after-empty',[adb,'-s',serial,'forward','--list']);assert before.stdout==after.stdout;checks.append('L53 empty and whitespace flags reject with usage errors before forwarding; --serial unknown')
 missing=start.copy();missing[missing.index('--application-id')+1]='com.grantiva.fix44.absent';p,elapsed=command('missing-app',missing,expected=1);assert elapsed<35 and b'Timed out' not in p.stderr,(elapsed,p.stderr);assert not session.exists();f,_=command('forwards-after-missing',[adb,'-s',serial,'forward','--list']);assert serial not in f.stdout.decode();checks.append({'L68 launch failure':'prompt, no session or forward','duration':elapsed})
 # A real killed keep-alive runner leaves a stale UIA session. Observe it before restarting.
 p,_=command('stale-first-start',start);old=json.loads(p.stdout);oldid=sessions(old['port'],'stale-old-session');os.kill(old['pid'],signal.SIGKILL);(d/'stale-signal.json').write_text(json.dumps({'pid':old['pid'],'signal':'SIGKILL','epoch':time.time()})+'\n');time.sleep(.1);assert sessions(old['port'],'stale-session-after-kill')==oldid
 p,_=command('stale-second-start',start);new=json.loads(p.stdout);newid=sessions(new['port'],'fresh-session');assert newid!=oldid and new['pid']!=old['pid'];tree,_=command('stale-immediate-tree',[binary,'runner','dump-hierarchy','--udid',serial,'--format','tree']);assert b'Landmarks' in tree.stdout;command('stale-stop',[binary,'runner','stop','--json']);assert not session.exists();f,_=command('forwards-after-stale',[adb,'-s',serial,'forward','--list']);assert serial not in f.stdout.decode();checks.append({'L68 stale session':'rejected and replaced','old':oldid,'new':newid,'oldPID':old['pid'],'newPID':new['pid']})
 for sub in ['flows','shared']:(project/sub).mkdir(exist_ok=True)
 (project/'flows/a.yaml').write_text('appId: com.kylebrowning.landmarks\n---\n- runFlow: ../shared/b.yaml\n');(project/'shared/b.yaml').write_text('appId: com.kylebrowning.landmarks\n---\n- runFlow: ../flows/a.yaml\n')
 for label,cwd in [('private',project),('alias',Path(str(project).replace('/private/tmp/','/tmp/',1)))]:
  p,elapsed=command('cycle-'+label,[binary,'run','--no-build','--platform','android','--device',serial,'--flow','flows/a.yaml'],expected=1,cwd=cwd);text=(p.stdout+p.stderr).decode();assert 'circular dependency detected: flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml' in text,text;assert elapsed<5,elapsed;checks.append({'L75 alias':label,'duration':elapsed,'exactFourHop':True})
finally:
 if session.exists():command('emergency-stop',[binary,'runner','stop','--json'],expected=None)
 (d/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps(checks,indent=2))
