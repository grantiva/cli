from pathlib import Path
import json,subprocess,socket,os,time
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());sdk=Path('/Users/kyle/Library/Android/sdk');adb=str(sdk/'platform-tools/adb');emulator=str(sdk/'emulator/emulator');avdm=str(sdk/'cmdline-tools/latest/bin/avdmanager');os.environ.pop('GRANTIVA_API_KEY',None);os.environ['JAVA_HOME']='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
before=subprocess.check_output([adb,'devices','-l']);(r/'android-devices-before-retry.txt').write_bytes(before);avds=subprocess.check_output([emulator,'-list-avds']);(r/'android-avds-before-retry.txt').write_bytes(avds)
assert b'emulator-5580' not in before and b'fix4-5-android' not in avds
for port in (5580,5581):
 with socket.socket() as sock:sock.bind(('127.0.0.1',port))
cmd=[avdm,'create','avd','-n','fix4-5-android','-k','system-images;android-35;google_apis;arm64-v8a','-d','pixel_8']
p=subprocess.run(cmd,input=b'no\n',capture_output=True);(r/'android-create-retry.out').write_bytes(p.stdout);(r/'android-create-retry.err').write_bytes(p.stderr);assert p.returncode==0,p.stderr
out=(r/'android-emulator.out').open('wb');err=(r/'android-emulator.err').open('wb');cmd=[emulator,'-avd','fix4-5-android','-port','5580','-no-window','-no-snapshot','-no-audio','-gpu','swiftshader_indirect']
p=subprocess.Popen(cmd,stdout=out,stderr=err,start_new_session=True);s['android']={'avd':'fix4-5-android','serial':'emulator-5580','emulatorPID':p.pid,'adb':adb,'emulator':emulator,'avdmanager':avdm};(r/'state.json').write_text(json.dumps(s,indent=2)+'\n');(r/'android-emulator-command.json').write_text(json.dumps(cmd));print(json.dumps(s['android']),flush=True)
for attempt in range(90):
 result=subprocess.run([adb,'-s','emulator-5580','shell','getprop','sys.boot_completed'],capture_output=True)
 if result.returncode==0 and result.stdout.strip()==b'1':print('Android boot complete',flush=True);break
 if p.poll() is not None:raise RuntimeError('emulator exited '+str(p.returncode))
 time.sleep(1)
else:raise TimeoutError('Android boot')
