import json,os,signal,subprocess,sys,time
from pathlib import Path
root,cwd,grantiva,udid=sys.argv[1:]
root=Path(root); cwd=Path(cwd)
cases=[('plain',[]),('quiet',['--quiet']),('json',['--json'])]
summary=[]
for name,mode in cases:
    session=cwd/'.grantiva/session.json'
    if session.exists(): raise SystemExit(f'{name}: pre-existing session')
    argv=[grantiva,'runner','start','--bundle-id','com.kylebrowning.Landmarks','--simulator',udid,'--platform','ios',*mode]
    (root/f'{name}.command.json').write_text(json.dumps(argv,indent=2))
    out=open(root/f'{name}.out','wb'); err=open(root/f'{name}.err','wb')
    p=subprocess.Popen(argv,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
    (root/f'{name}.pid').write_text(str(p.pid)+'\n')
    observed=[]; deadline=time.monotonic()+30
    while time.monotonic()<deadline and p.poll() is None:
        if session.exists():
            try:
                raw=session.read_text(); doc=json.loads(raw); observed.append(doc)
                (root/f'{name}.session-before-signal.json').write_text(json.dumps(doc,indent=2,sort_keys=True))
                break
            except Exception as e:(root/f'{name}.session-read-error.txt').write_text(repr(e))
        time.sleep(.05)
    if not observed:
        os.killpg(p.pid,signal.SIGINT); p.wait(timeout=30); out.close(); err.close(); raise SystemExit(f'{name}: no session before signal')
    sent=time.time(); os.killpg(p.pid,signal.SIGINT)
    try: rc=p.wait(timeout=30)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid,signal.SIGKILL);rc=p.wait();(root/f'{name}.forced-kill').write_text('true\n')
    out.close();err.close()
    (root/f'{name}.exit.txt').write_text(str(rc)+'\n')
    (root/f'{name}.timing.json').write_text(json.dumps({'signalEpoch':sent,'exitEpoch':time.time()},indent=2))
    for _ in range(100):
        if not session.exists():break
        time.sleep(.05)
    (root/f'{name}.session-after.txt').write_text('present\n' if session.exists() else 'absent\n')
    subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],stdout=open(root/f'{name}.ps-after.txt','wb'),stderr=subprocess.DEVNULL)
    summary.append({'name':name,'exit':rc,'sessionState':observed[-1].get('state'),'sessionAfter':session.exists()})
(root/'summary.json').write_text(json.dumps(summary,indent=2))
if any(x['exit']!=130 or x['sessionAfter'] for x in summary): raise SystemExit(1)
