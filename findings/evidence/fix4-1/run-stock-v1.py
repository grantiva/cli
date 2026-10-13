import datetime, hashlib, json, os, pathlib, subprocess, sys, time
root=pathlib.Path('/private/tmp/grantiva-fix4-1.6ddirwah')
evidence=pathlib.Path(__file__).parent
adb='/Users/kyle/Library/Android/sdk/platform-tools/adb'
serial='emulator-5580'
mode=sys.argv[1]
d=evidence/mode
d.mkdir()
env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None)
env.update(GRANTIVA_RUNNER_HOME=str(root/'runner-home'),MAESTRO_RUNNER_HOME=str(root/'runner-home'),GRANTIVA_SESSION_ID='fix4-1',PATH='/Users/kyle/Library/Android/sdk/platform-tools:'+env['PATH'])
identity=subprocess.check_output([adb,'-s',serial,'emu','avd','name'],text=True).splitlines()[0]
assert identity=='fix4-1-android', identity
load=os.getloadavg()[0]
assert load<15, load
flow=root/'flows'/('99-crash.yaml' if mode.startswith('stock-') else ('post-return.yaml' if mode=='post-return' else 'healthy.yaml'))
if mode=='post-return':
 flow.write_text('appId: com.kylebrowning.landmarks\n---\n- launchApp\n- extendedWaitUntil:\n    visible: "This never appears"\n    timeout: 10000\n')
subprocess.run([adb,'-s',serial,'logcat','-b','all','-c'],check=True,stdout=subprocess.DEVNULL)
cmd=['/Users/kyle/.grantiva-qa/bin/grantiva','run','--platform','android','--device',serial,'--emulator','fix4-1-android','--no-build','--verbose','--flow',str(flow),'--report-dir',str(d/'report')]
(d/'command.json').write_text(json.dumps({'argv':cmd,'loadBefore':load,'epoch':time.time(),'identity':identity,'flowSHA256':hashlib.sha256(flow.read_bytes()).hexdigest(),'environment':{k:env[k] for k in ['GRANTIVA_RUNNER_HOME','MAESTRO_RUNNER_HOME','GRANTIVA_SESSION_ID']}},indent=2))
(d/'input.yaml').write_bytes(flow.read_bytes())
began=time.monotonic();injected=False
with (d/'stdout.txt').open('w') as out,(d/'stderr.txt').open('w') as err:
 p=subprocess.Popen(cmd,cwd=root,env=env,stdout=out,stderr=err)
 (d/'runner-pid.txt').write_text(str(p.pid)+'\n')
 print(mode,'runner PID',p.pid,'load',load,flush=True)
 while p.poll() is None:
  if time.monotonic()-began>100:
   p.terminate();p.wait(timeout=10);raise RuntimeError('runner exceeded 100s')
  if mode=='post-return' and not injected:
   flow_files=list((d/'report/flows').glob('*.json'))
   for f in flow_files:
    try:data=json.loads(f.read_text())
    except (OSError,json.JSONDecodeError):continue
    if data.get('commands') and data['commands'][0]['status']=='passed':
     crashcmd=[adb,'-s',serial,'shell','am','crash','com.kylebrowning.landmarks']
     (d/'injection.json').write_text(json.dumps({'epoch':time.time(),'argv':crashcmd,'passedLaunch':data['commands'][0]},indent=2))
     with (d/'injection.out').open('w') as f:subprocess.run(crashcmd,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=5)
     injected=True
  time.sleep(.05)
rc=p.returncode
(d/'processes-after.txt').write_bytes(subprocess.check_output(['ps','-axo','pid,ppid,command']))
left=[line for line in (d/'processes-after.txt').read_text().splitlines() if 'adb -s '+serial+' shell logcat' in line]
with (d/'logcat.txt').open('w') as f:subprocess.run([adb,'-s',serial,'logcat','-b','all','-d','-v','epoch'],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=10)
(d/'result.json').write_text(json.dumps({'exitCode':rc,'elapsed':time.monotonic()-began,'endEpoch':time.time(),'collectorProcessesAfter':left,'injected':injected},indent=2))
print(mode,'exit',rc,'elapsed',time.monotonic()-began,'collector children left',len(left),flush=True)
assert not left,left
