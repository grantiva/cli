#!/usr/bin/env python3
"""Candidate4 exact-owned final cleanup. Root inspection and execution only."""
import hashlib, json, os, subprocess, sys, time
from pathlib import Path

ROOT=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-candidate4')
OUT=ROOT/'08-final-cleanup'
CANDIDATE=ROOT/'candidate.json'; CANDIDATE_SHA='714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783'
OWNERSHIP=ROOT/'provision/ownership.json'; OWNERSHIP_SHA='cbcf532932b9054fe39769976b4a790c814c77d80efb056d90f10b52c0290c30'
PROCESS_OWNERSHIP=ROOT/'provision/android-process/ownership.json'; PROCESS_OWNERSHIP_SHA='66011eae58ad483441efd572efa88c4237fe852c5443fc82f73fd839094e82a5'
IOS_BASELINE=ROOT/'provision/ios-before/stdout.raw'; IOS_BASELINE_SHA='f18f4c97e17febf897906c4c32b77386b9993022f05fcc840f1db19d819d0dd9'
IOS_ID='8BE033F1-0455-4BE3-A083-3132222D63C6'; IOS_NAME='smoke4-c4-ios'; IOS_RUNTIME='com.apple.CoreSimulator.SimRuntime.iOS-26-0'
AVD='smoke4-c4-android'; SERIAL='emulator-5580'; PID=39152
ADB='/Users/kyle/Library/Android/sdk/platform-tools/adb'; EMULATOR='/Users/kyle/Library/Android/sdk/emulator/emulator'; AVDMANAGER='/Users/kyle/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager'
JAVA_HOME='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
PIXEL=Path('/Users/kyle/.android/avd/Pixel_8_API_35.avd/config.ini'); PIXEL_SHA='3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27'
PROTECTED=('B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C','FE441EE5-BBFC-4981-B68A-59C0DBCE26D6')
ACCEPTANCES=(
 '02-runner-android/helper/acceptance.json','03-lifecycle-recorder-fix1/helper/acceptance.json','03b-joint-forward/helper/acceptance.json',
 '04-mcp-ios/helper/acceptance.json','05-mcp-android/helper/acceptance.json','06-docs-output/helper/acceptance.json','07-final-force-teardown/helper/acceptance.json')
PROJECTS=('android-smoke-project','cycle-project','lifecycle-project','mcp-android-project','mcp-ios-project','ready-forward-project')
STABLE_KEYS=('pid','pgid','sessionId','start','executable','command')

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('x') as stream: json.dump(value,stream,indent=2,sort_keys=True); stream.write('\n')
def accepted(doc): return doc.get('passed') is True or doc.get('accepted') is True or doc.get('status') in ('pass','passed','approved')
def raw(value): return value if isinstance(value,bytes) else (value or '').encode()
def run(name,argv,check=True,env=None,timeout=30):
    commands=OUT/'commands'; start=time.time(); command={'argv':argv,'cwd':str(ROOT),'start':start,'environment':env or {},'timeoutSeconds':timeout}
    write(commands/f'{name}-start.json',command)
    try:
        done=subprocess.run(argv,cwd=ROOT,env=({**os.environ,**(env or {})}),capture_output=True,timeout=timeout)
    except subprocess.TimeoutExpired as error:
        (commands/f'{name}.stdout.raw').write_bytes(raw(error.stdout)); (commands/f'{name}.stderr.raw').write_bytes(raw(error.stderr))
        command.update(end=time.time(),timedOut=True); write(commands/f'{name}.json',command)
        raise RuntimeError(f'{name} timed out after {timeout}s')
    (commands/f'{name}.stdout.raw').write_bytes(done.stdout); (commands/f'{name}.stderr.raw').write_bytes(done.stderr)
    command.update(end=time.time(),exit=done.returncode,timedOut=False); write(commands/f'{name}.json',command)
    if check and done.returncode: raise RuntimeError(f'{name} exited {done.returncode}')
    return done
def ps_field(field): return run(f'android-ps-{field}', ['/bin/ps','-ww','-p',str(PID),'-o',f'{field}=']).stdout.decode().strip()
def process_identity():
    result={'pid':int(ps_field('pid')),'ppid':int(ps_field('ppid')),'pgid':int(ps_field('pgid')),'sessionId':int(ps_field('sess')),
            'start':ps_field('lstart'),'executable':ps_field('comm'),'command':ps_field('command')}
    write(OUT/'android-process-current.json',result); return result
def sim_devices(doc): return [(runtime,item) for runtime,items in doc['devices'].items() for item in items]
def find_sim(doc,udid):
    matches=[(runtime,item) for runtime,item in sim_devices(doc) if item['udid']==udid]
    if len(matches)!=1: raise RuntimeError(f'simulator identity count for {udid}: {len(matches)}')
    return matches[0]
def protected(doc):
    keep=('dataPath','logPath','udid','lastUsedAt','isAvailable','deviceTypeIdentifier','state','name')
    return {udid:{'runtime':find_sim(doc,udid)[0],**{k:v for k,v in find_sim(doc,udid)[1].items() if k in keep}} for udid in PROTECTED}
def adb_serials(raw): return [line.split()[0] for line in raw.decode().splitlines()[1:] if len(line.split())>1]
def owned_state_absent(label):
    sessions=[]
    for project in PROJECTS:
        path=Path('/private/tmp/grantiva-completion-candidate4-x_i_t3pq')/project/'.grantiva/session.json'
        if path.exists(): sessions.append(str(path))
    global_dir=Path('/tmp/grantiva-sessions')
    if global_dir.exists():
        for path in global_dir.iterdir():
            if path.is_file():
                text=path.read_text(errors='replace')
                if IOS_ID in text or SERIAL in text or 'completion-candidate4' in text: sessions.append(str(path))
    locks=[]
    lock_root=Path('/private/tmp/grantiva-completion-candidate4-x_i_t3pq/runner-home/locks')
    for name in (f'{IOS_ID}.lock',f'{SERIAL}.lock'):
        if (lock_root/name).exists(): locks.append(str(lock_root/name))
    forwards=run(f'{label}-owned-forwards-check',[ADB,'forward','--list']).stdout.decode().splitlines()
    owned_forwards=[line for line in forwards if line.split() and line.split()[0]==SERIAL]
    state={'sessions':sessions,'leases':locks,'forwards':owned_forwards}; write(OUT/f'{label}-owned-state-check.json',state)
    if sessions or locks or owned_forwards: raise RuntimeError(f'owned session/lease/forward remains: {state}')

def main():
    if OUT.exists(): raise SystemExit(f'refusing existing output: {OUT}')
    OUT.mkdir(); (OUT/'commands').mkdir()
    try:
        for path,expected in ((CANDIDATE,CANDIDATE_SHA),(OWNERSHIP,OWNERSHIP_SHA),(PROCESS_OWNERSHIP,PROCESS_OWNERSHIP_SHA),(IOS_BASELINE,IOS_BASELINE_SHA),(PIXEL,PIXEL_SHA)):
            actual=sha(path); write(OUT/f'input-{path.name}-{expected[:8]}.json',{'path':str(path),'expected':expected,'actual':actual})
            if actual!=expected: raise RuntimeError(f'input hash mismatch: {path}')
        acceptance_bindings=[]
        for relative in ACCEPTANCES:
            path=ROOT/relative
            if not path.is_file(): raise RuntimeError(f'missing acceptance: {path}')
            doc=json.loads(path.read_text())
            if not accepted(doc): raise RuntimeError(f'acceptance not passed: {path}')
            acceptance_bindings.append({'path':str(path),'sha256':sha(path)})
        write(OUT/'acceptance-bindings.json',{'candidateManifest':str(CANDIDATE),'candidateSHA256':CANDIDATE_SHA,'required':acceptance_bindings})
        ownership=json.loads(OWNERSHIP.read_text()); process_owner=json.loads(PROCESS_OWNERSHIP.read_text())
        ios=ownership['devices']['ios']; android=ownership['devices']['android']; stable=process_owner['stableIdentity']
        if (ios['id'],ios['name'],ios['runtime'],ios['owned'])!=(IOS_ID,IOS_NAME,IOS_RUNTIME,True): raise RuntimeError('iOS ownership mismatch')
        if (android['id'],android['avd'],android['ownedPIDs'],android['owned'])!=(SERIAL,AVD,[PID],True): raise RuntimeError('Android ownership mismatch')
        if process_owner['serial']!=SERIAL or process_owner['avd']!=AVD: raise RuntimeError('process ownership target mismatch')
        current=process_identity()
        if {k:current[k] for k in STABLE_KEYS}!={k:stable[k] for k in STABLE_KEYS}: raise RuntimeError('Android stable identity mismatch')
        if f'-avd {AVD}' not in current['command'] or '-port 5580' not in current['command']: raise RuntimeError('Android argv target mismatch')
        sims_before=json.loads(run('simulators-before',['xcrun','simctl','list','devices','--json']).stdout)
        runtime,owned_sim=find_sim(sims_before,IOS_ID)
        if runtime!=IOS_RUNTIME or owned_sim['name']!=IOS_NAME: raise RuntimeError('current iOS name/runtime mismatch')
        baseline=json.loads(IOS_BASELINE.read_text()); protected_expected=protected(baseline); protected_before=protected(sims_before)
        write(OUT/'protected-before.json',protected_before)
        if protected_before!=protected_expected: raise RuntimeError('protected simulator pre-state differs from provision baseline')
        avd_name=run('android-avd-name',[ADB,'-s',SERIAL,'emu','avd','name']).stdout.decode().replace('\r','').splitlines()[0]
        if avd_name!=AVD: raise RuntimeError('live serial AVD-name mismatch')
        avds=run('avds-before',[EMULATOR,'-list-avds']).stdout.decode().splitlines()
        if AVD not in avds: raise RuntimeError('owned AVD registration absent')
        owned_state_absent('before')
        if owned_sim['state']=='Booted': run('ios-shutdown',['xcrun','simctl','shutdown',IOS_ID],timeout=120)
        elif owned_sim['state']=='Shutdown': write(OUT/'ios-shutdown-skipped.json',{'udid':IOS_ID,'state':'Shutdown','reason':'already shutdown'})
        else: raise RuntimeError(f'unexpected owned iOS state: {owned_sim["state"]}')
        run('ios-delete',['xcrun','simctl','delete',IOS_ID],timeout=120)
        run('android-kill',[ADB,'-s',SERIAL,'emu','kill'])
        absent=False
        for attempt in range(31):
            pid_done=run(f'wait-pid-{attempt}',['/bin/ps','-p',str(PID),'-o','pid='],check=False)
            adb_done=run(f'wait-adb-{attempt}',[ADB,'devices'])
            if pid_done.returncode!=0 and SERIAL not in adb_serials(adb_done.stdout): absent=True; break
            time.sleep(1)
        if not absent: raise RuntimeError('owned Android PID/serial did not disappear within 30 seconds')
        run('android-avd-delete',[AVDMANAGER,'delete','avd','--name',AVD],env={'JAVA_HOME':JAVA_HOME,'ANDROID_HOME':'/Users/kyle/Library/Android/sdk','ANDROID_SDK_ROOT':'/Users/kyle/Library/Android/sdk'},timeout=120)
        sims_after=json.loads(run('simulators-after',['xcrun','simctl','list','devices','--json']).stdout)
        if any(item['udid']==IOS_ID for _,item in sim_devices(sims_after)): raise RuntimeError('owned iOS simulator remains')
        protected_after=protected(sims_after); write(OUT/'protected-after.json',protected_after)
        if protected_after!=protected_expected: raise RuntimeError('protected simulator post-state differs from provision baseline')
        avds_after=run('avds-after',[EMULATOR,'-list-avds']).stdout.decode().splitlines()
        if AVD in avds_after: raise RuntimeError('owned Android AVD remains')
        if sha(PIXEL)!=PIXEL_SHA: raise RuntimeError('protected Pixel config changed')
        owned_state_absent('after')
        acceptance={'passed':True,'candidateManifestSHA256':CANDIDATE_SHA,'deletedIOS':IOS_ID,'deletedAndroid':AVD,'serial':SERIAL,'ownedPID':PID,'stableIdentityKeys':list(STABLE_KEYS),'ppidBound':False,'protectedSimulatorsUnchanged':True,'protectedPixelSHA256':PIXEL_SHA,'requiredAcceptances':list(ACCEPTANCES)}
        write(OUT/'acceptance.json',acceptance); return 0
    except Exception as error:
        write(OUT/'failure.json',{'passed':False,'error':repr(error),'time':time.time()}); return 1
if __name__=='__main__': sys.exit(main())
