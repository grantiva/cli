import json,os,signal,subprocess,sys,time
from pathlib import Path
root,cwd,grantiva,udid=sys.argv[1:]
root=Path(root); cwd=Path(cwd); summary=[]
for name,mode in [('plain',[]),('quiet',['--quiet']),('json',['--json'])]:
    session=cwd/'.grantiva/session.json'
    if session.exists(): raise SystemExit(f'{name}: pre-existing session')
    argv=[grantiva,'runner','start','--bundle-id','com.kylebrowning.Landmarks','--simulator',udid,'--platform','ios',*mode]
    (root/f'{name}.command.json').write_text(json.dumps(argv,indent=2))
    out=open(root/f'{name}.out','wb'); err=open(root/f'{name}.err','wb')
    p=subprocess.Popen(argv,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
    (root/f'{name}.pid').write_text(str(p.pid)+'\n')
    deadline=time.monotonic()+90; doc=None
    while time.monotonic()<deadline and p.poll() is None:
        if session.exists():
            try:
                candidate=json.loads(session.read_text())
                if candidate.get('state')=='ready' and candidate.get('udid')==udid and candidate.get('port'):
                    doc=candidate; break
            except Exception: pass
        time.sleep(.05)
    if doc is None:
        (root/f'{name}.pre-signal-state.txt').write_text(session.read_text(errors='replace') if session.exists() else 'absent\n')
        if p.poll() is None: os.kill(p.pid,signal.SIGINT)
        p.wait(timeout=30); out.close(); err.close(); raise SystemExit(f'{name}: no exact ready session')
    (root/f'{name}.session-before-signal.json').write_text(json.dumps(doc,indent=2,sort_keys=True))
    hierarchy=subprocess.run([grantiva,'runner','dump-hierarchy','--udid',udid],cwd=cwd,capture_output=True)
    (root/f'{name}.hierarchy.out').write_bytes(hierarchy.stdout); (root/f'{name}.hierarchy.err').write_bytes(hierarchy.stderr)
    (root/f'{name}.hierarchy.exit.txt').write_text(str(hierarchy.returncode)+'\n')
    if hierarchy.returncode != 0 or b'Landmarks' not in hierarchy.stdout:
        os.kill(p.pid,signal.SIGINT); p.wait(timeout=30); out.close(); err.close(); raise SystemExit(f'{name}: ready hierarchy failed')
    subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],stdout=open(root/f'{name}.ps-before.txt','wb'),stderr=subprocess.DEVNULL)
    sent=time.time(); os.kill(p.pid,signal.SIGINT)
    try: rc=p.wait(timeout=30)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid,signal.SIGKILL); rc=p.wait(); (root/f'{name}.forced-kill').write_text('true\n')
    out.close();err.close()
    for _ in range(100):
        if not session.exists(): break
        time.sleep(.05)
    (root/f'{name}.exit.txt').write_text(str(rc)+'\n'); (root/f'{name}.session-after.txt').write_text('present\n' if session.exists() else 'absent\n')
    (root/f'{name}.timing.json').write_text(json.dumps({'signalEpoch':sent,'exitEpoch':time.time()},indent=2))
    text=(root/f'{name}.err').read_text(errors='replace')
    summary.append({'name':name,'exit':rc,'readyState':doc.get('state'),'port':doc.get('port'),'hierarchyExit':hierarchy.returncode,'notice':('[grantiva] received SIGINT — releasing simulator and reaping child processes' in text),'sessionAfter':session.exists()})
(root/'summary.json').write_text(json.dumps(summary,indent=2))
if any(x['exit']!=130 or not x['notice'] or x['sessionAfter'] or x['hierarchyExit'] for x in summary): raise SystemExit(1)
