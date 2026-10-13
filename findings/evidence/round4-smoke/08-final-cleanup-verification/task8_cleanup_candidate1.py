from pathlib import Path
import subprocess,json,os,time,hashlib,shlex
r=Path.cwd();e=r/'findings/evidence/round4-smoke';o=e/'08-final-cleanup-attempt2';o.mkdir(exist_ok=False);scratch=Path('/private/tmp/grantiva-round4-smoke-j35_m7hg');home=scratch/'runner-home';adb='/Users/kyle/Library/Android/sdk/platform-tools/adb';serial='emulator-5580';udid='B718468C-771F-47BC-9CD8-A1143D540AC5';env=os.environ.copy();env['JAVA_HOME']='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
def run(n,a):
 t=time.time();p=subprocess.run(a,env=env,capture_output=True);(o/(n+'.stdout')).write_bytes(p.stdout);(o/(n+'.stderr')).write_bytes(p.stderr);(o/(n+'.json')).write_text(json.dumps({'argv':a,'start':t,'end':time.time(),'exit':p.returncode},indent=2)+'\n');return p
sims=json.loads(run('simulators-before',['xcrun','simctl','list','devices','--json']).stdout)
ownedios=[(runtime,d) for runtime,a in sims['devices'].items() for d in a if d['udid']==udid];assert len(ownedios)==1 and ownedios[0][1]['name']=='smoke4-ios' and ownedios[0][0]=='com.apple.CoreSimulator.SimRuntime.iOS-26-0'
assert run('shutdown-owned-ios',['xcrun','simctl','shutdown',udid]).returncode==0
assert run('delete-owned-ios',['xcrun','simctl','delete',udid]).returncode==0
assert run('owned-avd-identity',[adb,'-s',serial,'emu','avd','name']).stdout.decode().splitlines()[0]=='smoke4-android'
p=run('owned-emulator-pid',['/bin/ps','-ww','-p','28028','-o','pid=,command=']);assert 'smoke4-android' in p.stdout.decode()
f=run('forwards-before',[adb,'forward','--list']).stdout.decode();owned=[x.split() for x in f.splitlines() if x.startswith(serial+' ')]
for i,row in enumerate(owned):assert run('remove-exact-forward-'+str(i),[adb,'-s',serial,'forward','--remove',row[1]]).returncode==0
assert run('stop-owned-emulator',[adb,'-s',serial,'emu','kill']).returncode==0
for i in range(60):
 p=subprocess.run([adb,'devices'],capture_output=True)
 if serial not in p.stdout.decode():break
 time.sleep(.25)
assert serial not in p.stdout.decode()
assert run('delete-owned-avd',['/Users/kyle/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager','delete','avd','--name','smoke4-android']).returncode==0
safter=json.loads(run('simulators-after',['xcrun','simctl','list','devices','--json']).stdout);abefore=json.loads((e/'protected-before/simulators.stdout').read_text());protected=['B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C','FE441EE5-BBFC-4981-B68A-59C0DBCE26D6'];select=lambda x:{d['udid']:d for ds in x['devices'].values() for d in ds if d['udid'] in protected};assert select(abefore)==select(safter)
assert all(d['udid']!=udid for a in safter['devices'].values() for d in a)
after=run('android-after',[adb,'devices','-l']);assert serial not in after.stdout.decode();avds=run('avds-after',['/Users/kyle/Library/Android/sdk/emulator/emulator','-list-avds']).stdout.decode();assert 'smoke4-android' not in avds and 'Pixel_8_API_35' in avds
forward=run('forwards-after',[adb,'forward','--list']).stdout.decode();assert serial not in forward
ps=run('processes-after',['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']).stdout.decode();live=[]
for line in ps.splitlines():
 c=line.split(maxsplit=3)
 if len(c)!=4:continue
 try:a=shlex.split(c[3])
 except ValueError:continue
 if a and (Path(a[0]).name in ('grantiva-runner','xcodebuild','qemu-system-aarch64','emulator') or Path(a[0]).name.startswith('qemu-')) and any(x in a for x in (udid,serial,'smoke4-android')):live.append(line)
assert not live,live
sessions=[str(p) for p in scratch.glob('*/.grantiva/session.json')];assert not sessions,sessions
shared=[]
for p in Path('/tmp/grantiva-sessions').glob('*'):
 if p.is_file() and any(v in p.read_text(errors='replace') for v in (udid,serial,str(scratch))):shared.append(str(p))
assert not shared,shared
locks=[str(p) for p in [home/'locks'/f'{udid}.lock',home/'locks'/f'{serial}.lock'] if p.exists()];assert not locks,locks
cfg=Path('/Users/kyle/.android/avd/Pixel_8_API_35.avd/config.ini');h=hashlib.sha256(cfg.read_bytes()).hexdigest();assert h==json.loads((e/'protected-before/protected-avd.json').read_text())['sha256']
assert not Path('/Users/kyle/.android/avd/smoke4-android.avd').exists()
result={'passed':True,'deletedIOS':udid,'deletedAndroid':'smoke4-android','serial':serial,'ownedProcessesRemaining':live,'projectSessions':sessions,'sharedSessions':shared,'ownedDeviceLocks':locks,'protectedSimulatorsUnchanged':select(safter),'protectedAVDConfigSHA256':h,'forwardInventory':forward,'ordinaryInstallAndRegistryLockFiles':'Retained; not owned device leases or active locks.'};(o/'acceptance.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
