"""Controller provisions only new smoke-owned devices after candidate freeze."""
from pathlib import Path
import hashlib,json,os,subprocess,time
r=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression');e=r/'findings/evidence/round4-smoke-candidate3';c=json.loads((e/'candidate.json').read_text());state=json.loads((e/'initial-state.json').read_text());s=Path(state['scratch']);o=e/'provision';o.mkdir(exist_ok=False)
sdk=Path.home()/'Library/Android/sdk';adb=sdk/'platform-tools/adb';emulator=sdk/'emulator/emulator';avdmanager=sdk/'cmdline-tools/latest/bin/avdmanager';env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update(JAVA_HOME='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home',ANDROID_HOME=str(sdk),ANDROID_SDK_ROOT=str(sdk),GRANTIVA_RUNNER_HOME=state['runnerHome'],MAESTRO_RUNNER_HOME=state['runnerHome'],GRANTIVA_SESSION_ID='fix4-8-c3')
def save(name,data):(o/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
def run(label,argv,input=None,timeout=180):
 m={'argv':list(map(str,argv)),'cwd':str(s),'start':time.time(),'apiEnvironmentUnset':True,'runnerHome':state['runnerHome'],'session':'fix4-8-c3'}
 p=subprocess.run(m['argv'],cwd=s,env=env,capture_output=True,input=input,timeout=timeout);(o/(label+'.stdout')).write_bytes(p.stdout);(o/(label+'.stderr')).write_bytes(p.stderr);m.update(exit=p.returncode,end=time.time());save(label,m);assert p.returncode==0,(label,p.stderr.decode());return p.stdout.decode()
assert hashlib.sha256(Path(c['cli']['binary']['path']).read_bytes()).hexdigest()==c['cli']['binary']['sha256']
devices=json.loads(run('sims-before',['xcrun','simctl','list','devices','--json']));avds=run('avds-before',[emulator,'-list-avds']);android=run('android-before',[adb,'devices','-l']);run('forwards-before',[adb,'forward','--list'])
assert 'smoke4-c3-android' not in avds.splitlines() and 'emulator-5580' not in android
assert not any(x['name']=='smoke4-c3-ios' for group in devices['devices'].values() for x in group)
protected=Path.home()/'.android/avd/Pixel_8_API_35.avd/config.ini';save('protected-android',{'path':str(protected),'sha256':hashlib.sha256(protected.read_bytes()).hexdigest()})
own={'schema':'grantiva.task8.ownership.v1','sessionId':'fix4-8-c3','devices':{}}
argv=['xcrun','simctl','create','smoke4-c3-ios','com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro','com.apple.CoreSimulator.SimRuntime.iOS-26-0'];t=time.time();udid=run('ios-create',argv).strip();own['devices']['ios']={'platform':'ios','id':udid,'name':'smoke4-c3-ios','runtime':argv[-1],'owned':True,'createdEpoch':t,'provision':{'command':argv,'exit':0},'ownedPIDs':[]};save('ownership',own)
run('ios-boot',['xcrun','simctl','boot',udid]);run('ios-ready',['xcrun','simctl','bootstatus',udid,'-b'],timeout=240);run('ios-install',['xcrun','simctl','install',udid,c['demo']['iosApp']['path']])
container=Path(run('ios-installed-container',['xcrun','simctl','get_app_container',udid,'com.kylebrowning.Landmarks','app']).strip());actual=[{'path':str(x.relative_to(container)),'sha256':hashlib.sha256(x.read_bytes()).hexdigest()} for x in sorted(container.rglob('*')) if x.is_file()];assert actual==c['demo']['iosApp']['files'];save('ios-installed-manifest',{'sourceSHA':c['demo']['sourceSHA'],'files':actual,'path':str(container)})
argv=[str(avdmanager),'create','avd','--name','smoke4-c3-android','--package','system-images;android-35;google_apis;arm64-v8a','--device','pixel_8'];t=time.time();run('android-create',argv,b'no\n');own['devices']['android']={'platform':'android','id':'emulator-5580','name':'smoke4-c3-android','avd':'smoke4-c3-android','runtime':'API 35','owned':True,'createdEpoch':t,'provision':{'command':argv,'exit':0,'javaHome':env['JAVA_HOME']},'ownedPIDs':[]};save('ownership',own)
argv=[str(emulator),'-avd','smoke4-c3-android','-port','5580','-no-window','-no-audio','-no-snapshot'];so=(o/'emulator.stdout').open('wb');se=(o/'emulator.stderr').open('wb');proc=subprocess.Popen(argv,env=env,stdout=so,stderr=se,start_new_session=True);own['devices']['android']['ownedPIDs']=[proc.pid];save('ownership',own);save('android-launch',{'argv':argv,'pid':proc.pid,'start':time.time()});so.close();se.close()
run('android-wait',[adb,'-s','emulator-5580','wait-for-device'],timeout=180)
for n in range(90):
 assert proc.poll() is None,'owned emulator exited'
 if run('android-boot-'+str(n),[adb,'-s','emulator-5580','shell','getprop','sys.boot_completed']).strip()=='1':break
 time.sleep(1)
else:raise TimeoutError('owned emulator boot')
assert run('android-identity',[adb,'-s','emulator-5580','emu','avd','name']).splitlines()[0]=='smoke4-c3-android'
for name in ['mcp-ios-project','lifecycle-project','ios-log-project']:(s/name/'grantiva.yml').write_text('bundle_id: com.kylebrowning.Landmarks\nsimulator: '+udid+'\n')
save('acceptance',{'passed':True,'candidateManifestSHA256':hashlib.sha256((e/'candidate.json').read_bytes()).hexdigest(),'ownership':own});print(json.dumps(own,indent=2))
