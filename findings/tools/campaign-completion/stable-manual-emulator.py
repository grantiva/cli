#!/usr/bin/env python3
"""Launch or verify the one allocated manual Android emulator."""
import argparse, base64, json, os, socket, subprocess, sys, time
from pathlib import Path

SDK=Path('/Users/kyle/Library/Android/sdk'); EMULATOR=SDK/'emulator/emulator'; ADB=SDK/'platform-tools/adb'; PS=Path('/bin/ps')
AVD='cov4-android-2'; PORT=5556; SERIAL=f'emulator-{PORT}'

class ProbeFailure(RuntimeError):
    def __init__(self, record): super().__init__(record.get('error','probe failed')); self.record=record

def exclusive_json(path, value):
    with path.open('x') as stream: json.dump(value,stream,indent=2,sort_keys=True); stream.write('\n')

def remaining(deadline):
    value=deadline-time.monotonic()
    if value<=0: raise ProbeFailure({'error':'overall deadline expired','timedOut':True})
    return value

def timeout_stream(value):
    if value is None: return {'encoding':'base64','data':''}
    raw=value if isinstance(value,bytes) else value.encode('utf-8')
    return {'encoding':'base64','data':base64.b64encode(raw).decode('ascii')}

def probe(deadline, argv, accept_nonzero=False):
    record={'argv':argv,'startedEpoch':time.time()}
    try:
        done=subprocess.run(argv,text=True,capture_output=True,timeout=remaining(deadline))
        record.update(exit=done.returncode,stdout=done.stdout,stderr=done.stderr,endedEpoch=time.time())
    except subprocess.TimeoutExpired as error:
        record.update(error='probe timed out',timedOut=True,stdout=timeout_stream(error.stdout),stderr=timeout_stream(error.stderr),endedEpoch=time.time())
        raise ProbeFailure(record)
    if record['exit']!=0 and not accept_nonzero: record['error']='probe exited nonzero'; raise ProbeFailure(record)
    return record

def process_identity(pid, deadline):
    records=[]; values={}
    for key,field in (('pid','pid='),('ppid','ppid='),('pgid','pgid='),('sessionId','sess='),('start','lstart='),('executable','comm='),('command','command=')):
        item=probe(deadline,[str(PS),'-ww','-p',str(pid),'-o',field]); records.append(item); value=item['stdout'].strip()
        if not value: raise ProbeFailure({'error':f'missing process field {key}','probe':item})
        values[key]=int(value) if key in {'pid','ppid','pgid','sessionId'} else value
    return values,records

def stable_identity(value): return {key:value[key] for key in ('pid','pgid','sessionId','start','executable','command')}
def handoff_identity(value): return {key:value[key] for key in ('pid','pgid','sessionId','start')}
def expected_process(value): return all(token in value['command'] for token in ('qemu-system',f'-avd {AVD}',f'-port {PORT}'))

def device_state(deadline):
    calls=[[str(ADB),'-s',SERIAL,'get-state'],[str(ADB),'-s',SERIAL,'emu','avd','name'],[str(ADB),'-s',SERIAL,'shell','getprop','sys.boot_completed']]
    records=[probe(deadline,argv,accept_nonzero=True) for argv in calls]
    state={'state':records[0]['stdout'].strip(),'avd':records[1]['stdout'].replace('\r','').splitlines()[0] if records[1]['stdout'] else '', 'bootCompleted':records[2]['stdout'].strip()}
    return state,records

def preflight(deadline):
    adb=probe(deadline,[str(ADB),'devices']); attached=[line.split()[0] for line in adb['stdout'].splitlines()[1:] if line.split()]
    with socket.socket(socket.AF_INET,socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,0)
        try: listener.bind(('127.0.0.1',PORT)); free=True
        except OSError: free=False
    return {'adbProbe':adb,'attachedSerials':attached,'port':PORT,'portFree':free,'passed':SERIAL not in attached and free}

def terminal(evidence,stem,value): exclusive_json(evidence/f'{stem}-terminal.json',value)

def launch(evidence,timeout):
    evidence.mkdir(parents=True,exist_ok=False); deadline=time.monotonic()+timeout
    argv=[str(EMULATOR),'-avd',AVD,'-port',str(PORT),'-no-window','-no-snapshot-save']
    exclusive_json(evidence/'launch-pending.json',{'avd':AVD,'argv':argv,'hostStartEpoch':time.time(),'port':PORT,'serial':SERIAL})
    try:
        flight=preflight(deadline); exclusive_json(evidence/'preflight.json',flight)
        if not flight['passed']: raise ProbeFailure({'error':'reserved serial or port is not free','preflight':flight})
        with (evidence/'emulator.stdout.log').open('xb',buffering=0) as stdout,(evidence/'emulator.stderr.log').open('xb',buffering=0) as stderr:
            process=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,start_new_session=True,close_fds=True)
        exclusive_json(evidence/'launch-pid.json',{'pid':process.pid,'returnedEpoch':time.time()})
        provisional,probes=process_identity(process.pid,deadline)
        anchor=handoff_identity(provisional)
        exclusive_json(evidence/'launch-provisional-identity.json',{'identity':provisional,'identityProbes':probes,'handoffIdentity':anchor})
        observations=[]
        while True:
            if process.poll() is not None: raise ProbeFailure({'error':'emulator exited before readiness','exit':process.returncode,'observations':observations})
            current,current_probes=process_identity(process.pid,deadline)
            if handoff_identity(current)!=anchor: raise ProbeFailure({'error':'PID/start/group/session changed during startup handoff','identity':current,'probes':current_probes})
            state,records=device_state(deadline); observations.append({'device':state,'identity':current,'identityProbes':current_probes,'probes':records})
            probes_zero=all(record['exit']==0 for record in records)
            if expected_process(current) and probes_zero and state=={'state':'device','avd':AVD,'bootCompleted':'1'}:
                ownership={'avd':AVD,'argv':argv,'identity':current,'identityProbes':current_probes,'port':PORT,'serial':SERIAL,'stableIdentity':stable_identity(current)}
                exclusive_json(evidence/'ownership.json',ownership)
                terminal(evidence,'launch',{'ready':True,'device':state,'identity':current,'identityProbes':current_probes,'observations':observations}); return 0
            time.sleep(min(1.0,remaining(deadline)))
    except (ProbeFailure,ProcessLookupError,OSError) as error:
        record=error.record if isinstance(error,ProbeFailure) else {'error':repr(error)}; record.update(ready=False,observedEpoch=time.time())
        terminal(evidence,'launch',record); return 1

def next_verification(evidence):
    for number in range(1,1000):
        path=evidence/f'verification-{number:03d}-terminal.json'
        if not path.exists(): return path
    raise RuntimeError('verification record limit reached')

def verify(evidence,timeout):
    deadline=time.monotonic()+timeout; output=next_verification(evidence); result={'observedEpoch':time.time(),'verified':False}
    try:
        ownership=json.loads((evidence/'ownership.json').read_text()); pid=int(ownership['identity']['pid'])
        identity,iprobes=process_identity(pid,deadline); state,dprobes=device_state(deadline)
        result.update(device=state,deviceProbes=dprobes,identity=identity,identityMatches=stable_identity(identity)==ownership['stableIdentity'],identityProbes=iprobes,ppidAtLaunch=ownership['identity']['ppid'],ppidObserved=identity['ppid'],port=ownership['port'],serial=ownership['serial'])
        result['verified']=bool(result['identityMatches'] and expected_process(identity) and state=={'state':'device','avd':AVD,'bootCompleted':'1'})
    except (ProbeFailure,ProcessLookupError,OSError,KeyError,ValueError) as error:
        result['failure']=error.record if isinstance(error,ProbeFailure) else {'error':repr(error)}
    exclusive_json(output,result); return 0 if result['verified'] else 1

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('mode',choices=('launch','verify')); parser.add_argument('evidence',type=Path); parser.add_argument('--timeout',type=int,default=120); args=parser.parse_args()
    if args.timeout<=0: parser.error('--timeout must be positive')
    return launch(args.evidence,args.timeout) if args.mode=='launch' else verify(args.evidence,args.timeout)
if __name__=='__main__': sys.exit(main())
