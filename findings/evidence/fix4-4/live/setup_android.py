from pathlib import Path
import os,json,subprocess,time,socket,hashlib,shutil
r=Path(__file__).parent
assert not (r/'state.json').exists(), 'Retain prior setup; use a new attempt'
sdk=Path('/Users/kyle/Library/Android/sdk');adb=str(sdk/'platform-tools/adb');emu=str(sdk/'emulator/emulator');avdm=str(sdk/'cmdline-tools/latest/bin/avdmanager')
work=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-lifecycle-output');binary=str(work/'.build/debug/grantiva')
os.environ.pop('GRANTIVA_API_KEY',None);os.environ['JAVA_HOME']='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
def run(label,args,**kw):
 (r/(label+'.command.json')).write_text(json.dumps(args)+'\n')
 p=subprocess.run(args,capture_output=True,**kw);(r/(label+'.out')).write_bytes(p.stdout);(r/(label+'.err')).write_bytes(p.stderr);(r/(label+'.exit')).write_text(str(p.returncode)+'\n');assert p.returncode==0,(label,p.stderr);return p.stdout
before=run('android-devices-before',[adb,'devices','-l']);avds=run('android-avds-before',[emu,'-list-avds'])
assert b'emulator-5580' not in before and b'fix4-4-android' not in avds
for port in (5580,5581):
 with socket.socket() as sock:sock.bind(('127.0.0.1',port))
scratch=Path(subprocess.check_output(['/usr/bin/mktemp','-d','/private/tmp/grantiva-fix4-4.XXXXXX'],text=True).strip());home=scratch/'runner-home'
run('clone-runner-home',['/bin/cp','-cR','/Users/kyle/.grantiva/runner',str(home)])
project=scratch/'android-project';project.mkdir();(project/'grantiva-android.yml').write_text('application_id: com.kylebrowning.landmarks\nemulator: fix4-4-android\n')
apk_source=Path('/Users/kyle/Developer/landmarks-demo/android/app/build/outputs/apk/free/debug/app-free-debug.apk');apk=scratch/'Landmarks.apk';shutil.copyfile(apk_source,apk)
state={'sourceSHA':subprocess.check_output(['git','rev-parse','HEAD'],cwd=work,text=True).strip(),'binary':binary,'binarySHA256':hashlib.sha256(Path(binary).read_bytes()).hexdigest(),'bundle':str(work/'.build/debug/grantiva_GrantivaCore.bundle'),'scratch':str(scratch),'runnerHome':str(home),'sessionID':'fix4-4','android':{'avd':'fix4-4-android','serial':'emulator-5580','project':str(project),'adb':adb,'emulator':emu,'avdmanager':avdm,'apk':str(apk),'apkSource':str(apk_source),'apkSHA256':hashlib.sha256(apk.read_bytes()).hexdigest()}}
assert state['sourceSHA']=='9c7748523e703338887124a52a0a3af6d40a884b';assert state['android']['apkSHA256']=='c7e4dff77d8f08dd66105d045dede825c80ee137a742e03d8bc2b5979a7df626'
(r/'state.json').write_text(json.dumps(state,indent=2)+'\n');print(json.dumps(state),flush=True)
run('android-create',[avdm,'create','avd','-n','fix4-4-android','-k','system-images;android-35;google_apis;arm64-v8a','-d','pixel_8'],input=b'no\n')
args=[emu,'-avd','fix4-4-android','-port','5580','-no-window','-no-snapshot','-no-audio','-gpu','swiftshader_indirect'];(r/'android-emulator.command.json').write_text(json.dumps(args)+'\n')
p=subprocess.Popen(args,stdout=(r/'android-emulator.out').open('wb'),stderr=(r/'android-emulator.err').open('wb'),start_new_session=True)
state['android']['emulatorPID']=p.pid;(r/'state.json').write_text(json.dumps(state,indent=2)+'\n');print('owned emulator PID',p.pid,flush=True)
for attempt in range(180):
 q=subprocess.run([adb,'-s','emulator-5580','shell','getprop','sys.boot_completed'],capture_output=True)
 if q.returncode==0 and q.stdout.strip()==b'1':break
 if p.poll() is not None:raise RuntimeError('Owned emulator exited '+str(p.returncode))
 time.sleep(1)
else:raise TimeoutError('Owned Android boot')
run('android-identity',[adb,'-s','emulator-5580','emu','avd','name'])
run('android-install',[adb,'-s','emulator-5580','install','-r',str(apk)])
print('Owned Android booted and app installed',flush=True)
