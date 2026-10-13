import atexit, json, os, signal, subprocess, sys, threading, time
from pathlib import Path

root, project, grantiva, udid = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
owned_parents=[]

def cleanup():
    lines=[]
    for p in owned_parents:
        if p.poll() is None:
            try: os.kill(p.pid,signal.SIGINT); lines.append(f'SIGINT parent {p.pid}')
            except ProcessLookupError: pass
            try: p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                try: os.kill(p.pid,signal.SIGTERM); lines.append(f'SIGTERM parent {p.pid}')
                except ProcessLookupError: pass
    cp=subprocess.run([grantiva,'runner','stop','--json'],cwd=project,text=True,capture_output=True,timeout=30)
    (root/'cleanup-stop.out').write_text(cp.stdout or '')
    (root/'cleanup-stop.err').write_text(cp.stderr or '')
    (root/'cleanup-stop.exit.txt').write_text(str(cp.returncode)+'\n')
    (root/'cleanup-actions.txt').write_text('\n'.join(lines)+'\n')
atexit.register(cleanup)

def save(name, cp):
    (root/f"{name}.out").write_text(cp.stdout or "")
    (root/f"{name}.err").write_text(cp.stderr or "")
    (root/f"{name}.exit.txt").write_text(str(cp.returncode)+"\n")

def run(name, args, timeout=60):
    cp=subprocess.run(args,cwd=project,text=True,capture_output=True,timeout=timeout)
    save(name,cp); return cp

def session_for_pid(pid):
    p=Path(f"/tmp/grantiva-sessions/{pid}.owner.json")
    if p.exists(): return json.loads(p.read_text())
    return None

def wait_owner(exclude=(), timeout=45):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        for p in Path('/tmp/grantiva-sessions').glob('*.owner.json'):
            try: d=json.loads(p.read_text())
            except Exception: continue
            if str(d.get('udid'))==udid and int(d.get('pid',p.name.split('.')[0])) not in exclude:
                (root/f"owner-{d.get('pid',p.name.split('.')[0])}.json").write_text(p.read_text())
                return d
        time.sleep(.1)
    raise RuntimeError('owner sidecar not observed')

def alive(pid):
    try: os.kill(pid,0); return True
    except ProcessLookupError: return False

def live_not_zombie(pid):
    cp=subprocess.run(['ps','-o','state=','-p',str(pid)],text=True,capture_output=True)
    state=cp.stdout.strip()
    return bool(state) and not state.startswith('Z')

# Blocked-mask/verbose-stop leg is retained in attempt89e.
pid=-1

flow=project/'.maestro/01-browse.yaml'
def nohup_run(tag):
    ready=root/f'{tag}-ready.json'
    out=open(root/f'{tag}-parent.out','w'); err=open(root/f'{tag}-parent.err','w')
    def ignore_hup(): signal.signal(signal.SIGHUP,signal.SIG_IGN)
    p=subprocess.Popen([grantiva,'run','--no-build','--simulator',udid,'--flow',str(flow),'--keep-alive','--ready-file',str(ready)],cwd=project,stdout=out,stderr=err,start_new_session=True,preexec_fn=ignore_hup)
    owned_parents.append(p)
    (root/f'{tag}-parent.pid').write_text(str(p.pid)+'\n')
    owner=wait_owner({pid}); rpid=int(owner.get('runnerPid') or owner.get('pid')); (root/f'{tag}-runner.pid').write_text(str(rpid)+'\n')
    end=time.monotonic()+60
    while time.monotonic()<end:
        if ready.exists():
            try:
                rd=json.loads(ready.read_text())
                if rd.get('status') in ('passed','failed','interrupted'): break
            except Exception: pass
        if p.poll() is not None: raise RuntimeError(f'{tag} parent exited {p.returncode}')
        time.sleep(.2)
    else: raise RuntimeError(f'{tag} ready timeout')
    run(tag+'-ps',['ps','-o','pid=,sigmask=,command=','-p',f'{p.pid},{rpid}'])
    return p,rpid,out,err

# HUP survival/hierarchy is retained in attempt89f. Re-prove normal stop while
# concurrently reaping the owning Popen so runner stop cannot wait on a zombie.
p1,r1,o1,e1=nohup_run('normal')
box={}
def do_stop(): box['cp']=run('normal-stop',[grantiva,'runner','stop','--verbose','--json'])
t=threading.Thread(target=do_stop); t.start(); rc=p1.wait(timeout=30); t.join(timeout=35)
o1.close(); e1.close(); (root/'normal-parent.exit.txt').write_text(str(rc)+'\n')
assert not t.is_alive() and box['cp'].returncode==0 and rc==0

# Dead-runner control: parent notices SIGKILL promptly and sidecars disappear.
p2,r2,o2,e2=nohup_run('killed')
t0=time.monotonic(); os.kill(r2,signal.SIGKILL); rc=p2.wait(timeout=20); elapsed=time.monotonic()-t0
o2.close(); e2.close(); (root/'killed-parent.exit.txt').write_text(str(rc)+'\n'); (root/'killed-detection-seconds.txt').write_text(f'{elapsed:.3f}\n')
assert rc!=0 and elapsed<20
time.sleep(1)
left=sorted(str(x) for x in Path('/tmp/grantiva-sessions').glob(f'{r2}*'))
(root/'killed-sidecars-after.json').write_text(json.dumps(left,indent=2)+'\n'); assert not left
run('final-stop',[grantiva,'runner','stop','--json'])
(root/'completed').write_text('ok\n')
