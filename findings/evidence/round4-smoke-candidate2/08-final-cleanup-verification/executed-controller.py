"""Delete only candidate-2 controller-owned devices and verify final isolation."""
from pathlib import Path
import argparse,hashlib,json,os,shlex,subprocess,time

p=argparse.ArgumentParser();p.add_argument('--evidence-root',default='/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/round4-smoke-candidate2');p.add_argument('--output');a=p.parse_args()
e=Path(a.evidence_root).resolve();state_path=e/'initial-state.json';candidate_path=e/'candidate.json';ownership_path=e/'provision/ownership.json';state=json.loads(state_path.read_text());candidate=json.loads(candidate_path.read_text());ownership=json.loads(ownership_path.read_text());scratch=Path(state['scratch']).resolve();home=Path(state['runnerHome']).resolve();o=Path(a.output).resolve() if a.output else e/'08-final-cleanup';o.mkdir(parents=True,exist_ok=False)
sdk=Path.home()/'Library/Android/sdk';adb=sdk/'platform-tools/adb';emulator=sdk/'emulator/emulator';avdmanager=sdk/'cmdline-tools/latest/bin/avdmanager';env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update(JAVA_HOME='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home',ANDROID_HOME=str(sdk),ANDROID_SDK_ROOT=str(sdk),GRANTIVA_RUNNER_HOME=str(home),MAESTRO_RUNNER_HOME=str(home),GRANTIVA_SESSION_ID='fix4-8')
failures=[];actions=[]
def save(name,value):(o/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def fail(message):failures.append(message);save('failures',failures)
def run(label,argv,timeout=180):
 d=o/'commands';d.mkdir(exist_ok=True);argv=list(map(str,argv));m={'argv':argv,'cwd':str(scratch),'javaHome':env['JAVA_HOME'],'runnerHome':str(home),'apiEnvironmentUnset':True,'session':'fix4-8','start':time.time()}
 try:q=subprocess.run(argv,cwd=scratch,env=env,capture_output=True,timeout=timeout);m.update(exit=q.returncode,end=time.time());stdout=q.stdout;stderr=q.stderr
 except Exception as ex:m.update(exit=None,end=time.time(),exception=repr(ex));stdout=b'';stderr=str(ex).encode()
 (d/(label+'.stdout')).write_bytes(stdout);(d/(label+'.stderr')).write_bytes(stderr);save('commands/'+label,m);return m,stdout,stderr
def require(value,message):
 if not value:fail(message)
 return bool(value)
def normalized_simulators(doc,ids):
 return {d['udid']:{k:v for k,v in d.items() if k not in ('dataPathSize','logPathSize')} for group in doc['devices'].values() for d in group if d['udid'] in ids}
def simulator_matches(doc,record):
 found=[(runtime,d) for runtime,group in doc['devices'].items() for d in group if d.get('udid')==record['id']]
 return found if len(found)==1 and found[0][0]==record['runtime'] and found[0][1].get('name')==record['name'] else []
def ps_rows(label):
 m,stdout,_=run(label,['/bin/ps','-ww','-axo','pid=,ppid=,pgid=,command=']);rows=[]
 if m['exit']!=0:fail(label+' failed');return rows
 for line in stdout.decode(errors='replace').splitlines():
  fields=line.strip().split(None,3)
  if len(fields)!=4:continue
  try:argv=shlex.split(fields[3])
  except ValueError:continue
  rows.append({'pid':int(fields[0]),'ppid':int(fields[1]),'pgid':int(fields[2]),'command':fields[3],'argv':argv})
 save(label+'-parsed',rows);return rows
def process_alive(pid,rows):return next((row for row in rows if row['pid']==pid),None)
def exact_emulator_process(row):
 if row is None:return False
 argv=row['argv'];base=Path(argv[0]).name if argv else ''
 def value(flag):
  return argv[argv.index(flag)+1] if flag in argv and argv.index(flag)+1<len(argv) else None
 return row['pid']==emulator_pid and (base=='emulator' or base.startswith('qemu-')) and value('-avd')==avd and value('-port')=='5580'

assert state_path.is_file() and candidate_path.is_file() and ownership_path.is_file()
assert candidate.get('schema')=='grantiva.task8.candidate.v1' and ownership.get('schema')=='grantiva.task8.ownership.v1' and ownership.get('sessionId')=='fix4-8'
assert Path(candidate['runner']['runnerHome']).resolve()==home and scratch==Path(state['scratch']).resolve()
ios=ownership['devices']['ios'];android=ownership['devices']['android'];assert ios.get('owned') is True and android.get('owned') is True
assert ios['platform']=='ios' and ios['name']=='smoke4-ios' and ios['runtime']=='com.apple.CoreSimulator.SimRuntime.iOS-26-0' and ios.get('createdEpoch')
assert android['platform']=='android' and android['id']=='emulator-5580' and android['name']==android['avd']=='smoke4-android' and android['runtime']=='API 35' and android.get('createdEpoch')
assert android['provision'].get('javaHome')==env['JAVA_HOME'] and len(android.get('ownedPIDs',[]))==1;emulator_pid=int(android['ownedPIDs'][0])
assert ios['provision']['command']==['xcrun','simctl','create','smoke4-ios','com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro',ios['runtime']] and ios['provision']['exit']==0
expected_android_create=[str(avdmanager),'create','avd','--name','smoke4-android','--package','system-images;android-35;google_apis;arm64-v8a','--device','pixel_8'];assert android['provision']['command']==expected_android_create and android['provision']['exit']==0
udid=ios['id'];serial=android['id'];avd=android['avd'];protected_ids={'B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C','FE441EE5-BBFC-4981-B68A-59C0DBCE26D6'};assert udid not in protected_ids
protected_before=json.loads((e/'provision/sims-before.stdout').read_text());protected_snapshot=normalized_simulators(protected_before,protected_ids);assert set(protected_snapshot)==protected_ids
protected_android=json.loads((e/'provision/protected-android.json').read_text());protected_config=Path(protected_android['path']);assert protected_config==Path.home()/'.android/avd/Pixel_8_API_35.avd/config.ini'

# Authenticate and collect only candidate-owned session state. Unknown files are evidence, never broad cleanup targets.
project_sessions=[];claimed_pids=set()
for path in sorted(scratch.rglob('.grantiva/session.json')):
 raw=path.read_bytes()
 try:doc=json.loads(raw)
 except Exception:doc={}
 identifiers={str(doc.get(k,'')) for k in ('udid','device','deviceId')};owned=bool(identifiers&{udid,serial}) or udid.encode() in raw or serial.encode() in raw
 if not owned:fail('refused unknown project session '+str(path));continue
 for key in ('pid','runnerPid','runnerPID'):
  if isinstance(doc.get(key),int):claimed_pids.add(doc[key])
 project_sessions.append({'path':str(path),'sha256':hashlib.sha256(raw).hexdigest(),'document':doc})
save('project-sessions-before',project_sessions)
global_owned=[]
global_root=Path('/tmp/grantiva-sessions')
if global_root.exists():
 for path in sorted(global_root.iterdir()):
  if not path.is_file():continue
  raw=path.read_bytes();owned=any(marker in raw for marker in (udid.encode(),serial.encode(),str(scratch).encode())) or any(path.name.startswith(str(pid)) for pid in claimed_pids)
  if owned:
   try:doc=json.loads(raw)
   except Exception:doc={}
   for key in ('pid','runnerPid','runnerPID'):
    if isinstance(doc.get(key),int):claimed_pids.add(doc[key])
   global_owned.append({'path':str(path),'sha256':hashlib.sha256(raw).hexdigest(),'document':doc})
save('global-sessions-before',global_owned)

rows=ps_rows('processes-before');known=[];unknown=[];installed=Path(candidate['runner']['installed']['path']).resolve();candidate_binary=Path(candidate['cli']['binary']['path']).resolve()
for row in rows:
 argv=row['argv'];joined=' '.join(argv);base=Path(argv[0]).name if argv else '';marked=any(x in joined for x in (udid,serial,avd,str(scratch))) or row['pid'] in claimed_pids
 if not marked:continue
 exact=False;kind=None
 if exact_emulator_process(row):exact=True;kind='owned-emulator'
 elif Path(argv[0]).resolve()==installed and (udid in argv or serial in argv or row['pid'] in claimed_pids):exact=True;kind='owned-runner'
 elif base in ('xcodebuild','log','simctl') and (udid in joined or str(scratch) in joined or row['pid'] in claimed_pids):exact=True;kind='owned-wda-log'
 elif Path(argv[0]).resolve()==candidate_binary and row['pid'] in claimed_pids:exact=True;kind='owned-cli'
 if exact:known.append(dict(row,kind=kind))
 else:unknown.append(row)
save('owned-processes-before',known);save('unknown-marker-processes-before',unknown)
if unknown:fail('refused unknown processes carrying owned markers')

# Stop exact runner/WDA/log/CLI processes first. The emulator is stopped only through its authenticated device/PID branch below.
terminated_pids=[]
for row in known:
 if row['kind']=='owned-emulator':continue
 m,_,_=run('terminate-'+row['kind']+'-'+str(row['pid']),['/bin/kill','-TERM',str(row['pid'])]);actions.append({'kind':row['kind'],'pid':row['pid'],'exit':m['exit']})
 if m['exit']!=0:fail('failed targeted process termination '+str(row['pid']))
 else:terminated_pids.append(row['pid'])
process_cleanup_safe=True
for pid in terminated_pids:
 for attempt in range(20):
  check,_,_=run('wait-owned-process-'+str(pid)+'-'+str(attempt),['/bin/ps','-p',str(pid),'-o','stat='])
  if check['exit']!=0:break
  time.sleep(.25)
 else:fail('targeted process remained after TERM '+str(pid));process_cleanup_safe=False

# Remove only authenticated owned session and lease records; ordinary install/registry locks remain untouched.
if process_cleanup_safe:
 for index,item in enumerate(project_sessions+global_owned):
  path=Path(item['path']);m,_,_=run('unlink-owned-session-'+str(index),['/usr/bin/unlink',path]);actions.append({'kind':'owned-session','path':str(path),'exit':m['exit']})
  if m['exit']!=0:fail('failed owned session unlink '+str(path))
for identifier in (udid,serial):
 path=home/'locks'/(identifier+'.lock')
 if path.exists():
  raw=path.read_bytes();require(identifier.encode() in raw,'refused lease without matching device identity '+str(path))
  if process_cleanup_safe and identifier.encode() in raw:
   m,_,_=run('unlink-owned-lease-'+identifier,['/usr/bin/unlink',path]);actions.append({'kind':'owned-lease','path':str(path),'exit':m['exit']})
   if m['exit']!=0:fail('failed owned lease unlink '+str(path))

# Force-teardown JSON proves resource reclamation only; physical simulator deletion is authenticated and performed here.
m,stdout,_=run('simulators-before',['xcrun','simctl','list','devices','--json']);sims=json.loads(stdout) if m['exit']==0 else {'devices':{}};ios_found=simulator_matches(sims,ios)
if any(d.get('udid')==udid for group in sims.get('devices',{}).values() for d in group) and not ios_found:fail('refused iOS deletion: ownership name/runtime mismatch')
elif ios_found:
 shutdown,_,_=run('shutdown-owned-ios',['xcrun','simctl','shutdown',udid]);actions.append({'kind':'ios-shutdown','id':udid,'exit':shutdown['exit']})
 delete,_,_=run('delete-owned-ios',['xcrun','simctl','delete',udid]);actions.append({'kind':'ios-delete','id':udid,'exit':delete['exit']})
 if delete['exit']!=0:fail('owned iOS delete failed')

# Authenticate serial, AVD, and the provision-recorded emulator PID before any Android action.
m,stdout,_=run('android-devices-before',[adb,'devices','-l']);serial_live=m['exit']==0 and any(line.split() and line.split()[0]==serial for line in stdout.decode().splitlines()[1:])
rows=ps_rows('android-process-identity');pid_row=process_alive(emulator_pid,rows);pid_ok=pid_row is None or exact_emulator_process(pid_row)
avd_ok=True
if serial_live:
 identity,identity_out,_=run('owned-avd-identity',[adb,'-s',serial,'emu','avd','name']);avd_ok=identity['exit']==0 and identity_out.decode().splitlines() and identity_out.decode().splitlines()[0]==avd
require(avd_ok,'refused Android cleanup: live serial AVD mismatch');require(pid_ok,'refused Android cleanup: owned PID command mismatch')
if avd_ok and pid_ok:
 forwards,forward_out,_=run('forwards-before',[adb,'forward','--list'])
 if forwards['exit']==0:
  for index,row in enumerate(x.split() for x in forward_out.decode().splitlines() if x.startswith(serial+' ')):
   remove,_,_=run('remove-owned-forward-'+str(index),[adb,'-s',serial,'forward','--remove',row[1]]);actions.append({'kind':'owned-forward','value':row,'exit':remove['exit']})
   if remove['exit']!=0:fail('failed exact forward removal '+row[1])
 if serial_live:
  stop,_,_=run('stop-owned-emulator',[adb,'-s',serial,'emu','kill']);actions.append({'kind':'android-stop','serial':serial,'exit':stop['exit']})
  if stop['exit']!=0:fail('owned emulator stop failed')
 elif pid_row and exact_emulator_process(pid_row):
  stop,_,_=run('stop-owned-emulator-pid',['/bin/kill','-TERM',str(emulator_pid)]);actions.append({'kind':'android-stop-pid','pid':emulator_pid,'exit':stop['exit']})
  if stop['exit']!=0:fail('owned emulator PID stop failed')
 for attempt in range(60):
  check,device_out,_=run('android-wait-absent-'+str(attempt),[adb,'devices'])
  if check['exit']==0 and serial not in device_out.decode():break
  time.sleep(.25)
 avds,avd_out,_=run('avds-before-delete',[emulator,'-list-avds']);avd_dir=Path.home()/'.android/avd'/(avd+'.avd');config=avd_dir/'config.ini'
 if avds['exit']==0 and avd in avd_out.decode().splitlines():
  config_fields={k.strip():v.strip() for line in config.read_text(errors='replace').splitlines() if '=' in line for k,v in [line.split('=',1)]} if config.is_file() else {}
  config_ok=config_fields.get('AvdId')==avd and config_fields.get('avd.ini.displayname')==avd
  require(config_ok,'refused AVD deletion: exact config identity missing')
  if config_ok:
   delete,_,_=run('delete-owned-avd',[avdmanager,'delete','avd','--name',avd]);actions.append({'kind':'android-avd-delete','avd':avd,'exit':delete['exit']})
   if delete['exit']!=0:fail('owned AVD delete failed')

# Final verification is independent of overall smoke success.
m,stdout,_=run('simulators-after',['xcrun','simctl','list','devices','--json']);safter=json.loads(stdout) if m['exit']==0 else {'devices':{}};require(m['exit']==0,'final simulator inventory failed');require(not any(d.get('udid')==udid for group in safter['devices'].values() for d in group),'owned iOS remains');protected_after=normalized_simulators(safter,protected_ids);require(protected_after==protected_snapshot,'protected simulator metadata changed')
m,stdout,_=run('android-after',[adb,'devices','-l']);require(m['exit']==0 and serial not in stdout.decode(),'owned Android serial remains')
m,stdout,_=run('avds-after',[emulator,'-list-avds']);require(m['exit']==0 and avd not in stdout.decode().splitlines() and 'Pixel_8_API_35' in stdout.decode().splitlines(),'owned AVD remains or protected AVD missing')
m,stdout,_=run('forwards-after',[adb,'forward','--list']);require(m['exit']==0 and not any(x.startswith(serial+' ') for x in stdout.decode().splitlines()),'owned forwards remain')
after_rows=ps_rows('processes-after');remaining=[]
for row in after_rows:
 joined=' '.join(row['argv'])
 if any(x in joined for x in (udid,serial,avd,str(scratch))) or row['pid'] in claimed_pids or row['pid']==emulator_pid:remaining.append(row)
require(not remaining,'owned or unknown marked processes remain');save('owned-processes-after',remaining)
sessions_after=[str(path) for path in scratch.rglob('.grantiva/session.json')];shared_after=[]
if global_root.exists():
 for path in global_root.iterdir():
  if path.is_file():
   raw=path.read_bytes()
   if any(marker in raw for marker in (udid.encode(),serial.encode(),str(scratch).encode())) or any(path.name.startswith(str(pid)) for pid in claimed_pids):shared_after.append(str(path))
leases_after=[str(home/'locks'/(identifier+'.lock')) for identifier in (udid,serial) if (home/'locks'/(identifier+'.lock')).exists()];require(not sessions_after,'project sessions remain');require(not shared_after,'global sessions remain');require(not leases_after,'owned leases remain')
protected_hash=sha(protected_config);require(protected_hash==protected_android['sha256'],'protected Pixel config changed')
result={'passed':not failures,'candidateManifest':str(candidate_path),'ownershipManifest':str(ownership_path),'deletedIOS':udid,'deletedAndroid':avd,'serial':serial,'ownedPID':emulator_pid,'actions':actions,'failures':failures,'ownedProcessesRemaining':remaining,'projectSessions':sessions_after,'globalSessions':shared_after,'ownedLeases':leases_after,'ownedForwardsAbsent':not any(x.startswith(serial+' ') for x in stdout.decode().splitlines()),'protectedSimulatorsUnchanged':protected_after,'protectedAVDConfigSHA256':protected_hash,'forceTeardownPhysicalDeletionAssumed':False}
save('acceptance',result);print(json.dumps(result,indent=2));raise SystemExit(0 if result['passed'] else 1)
