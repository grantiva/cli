import json, os, signal, subprocess, sys, time
out, project, grantiva, serial = sys.argv[1:]
os.makedirs(out, exist_ok=True)
current=None

def write(path, value):
    with open(os.path.join(out,path),'w') as f: f.write(str(value))

def wait_session(proc, timeout=120):
    p=os.path.join(project,'.grantiva','session.json')
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        if proc.poll() is not None: raise RuntimeError(f'foreground exited early {proc.returncode}')
        try:
            d=json.load(open(p))
            if d.get('state')=='ready' and d.get('platform')=='android' and (d.get('serial')==serial or d.get('udid')==serial) and isinstance(d.get('pid'),int): return p,d
        except (FileNotFoundError,json.JSONDecodeError): pass
        time.sleep(.1)
    raise RuntimeError('ready timeout')

def start(name, extra):
    d=os.path.join(out,name); os.makedirs(d)
    argv=[grantiva,'runner','start','--device',serial]+extra
    write(name+'/argv.json',json.dumps(argv))
    so=open(os.path.join(d,'stdout.log'),'w'); se=open(os.path.join(d,'stderr.log'),'w')
    p=subprocess.Popen(argv,cwd=project,stdout=so,stderr=se,text=True)
    write(name+'/grantiva-pid.txt',p.pid)
    return p,so,se

def close_wait(name,p,so,se,timeout=60):
    rc=p.wait(timeout=timeout); so.close(); se.close(); write(name+'/exit.txt',rc); return rc

fail=[]
try:
    # Five orderly foreground stops. Cycle 1 stops immediately after first hierarchy answer.
    for i in range(1,6):
        name=f'stop-{i}'
        p,so,se=start(name,[]); current=p
        sp,sd=wait_session(p); write(name+'/session-ready.json',json.dumps(sd,indent=2))
        if i==1:
            h=subprocess.run([grantiva,'runner','dump-hierarchy','--udid',serial],cwd=project,capture_output=True,text=True)
            response_end=time.monotonic()
            write(name+'/hierarchy.out',h.stdout); write(name+'/hierarchy.err',h.stderr); write(name+'/hierarchy.exit.txt',h.returncode)
            if h.returncode!=0: fail.append(name+' hierarchy')
        stop_start=time.monotonic()
        if i==1: write(name+'/hierarchy-response-to-stop-start-seconds.txt',f'{stop_start-response_end:.6f}')
        st=subprocess.run([grantiva,'runner','stop'],cwd=project,capture_output=True,text=True)
        write(name+'/stop.out',st.stdout); write(name+'/stop.err',st.stderr); write(name+'/stop.exit.txt',st.returncode)
        rc=close_wait(name,p,so,se)
        text=open(os.path.join(out,name,'stdout.log')).read()+open(os.path.join(out,name,'stderr.log')).read()
        if st.returncode!=0 or rc!=0 or 'Runner stopped (pid ' not in text or 'the session has ended.' not in text: fail.append(name)
        if os.path.exists(sp): fail.append(name+' session remains')
    # Unprompted runner death: kill only the exact runner PID from this foreground session.
    p,so,se=start('runner-kill',[]); current=p; sp,sd=wait_session(p); write('runner-kill/session-ready.json',json.dumps(sd,indent=2))
    rpid=sd['pid']; write('runner-kill/owned-runner-pid.txt',rpid)
    ps=subprocess.run(['/bin/ps','-o','pid=,ppid=,command=','-p',str(rpid)],capture_output=True,text=True)
    write('runner-kill/runner-ps.txt',ps.stdout)
    parts=ps.stdout.strip().split(None,2)
    if ps.returncode!=0 or len(parts)!=3 or int(parts[0])!=rpid or int(parts[1])!=p.pid or 'grantiva-runner' not in parts[2] or '--platform android' not in parts[2] or ('--device '+serial) not in parts[2]:
        raise RuntimeError('runner PID identity guard failed: '+ps.stdout)
    os.kill(rpid,signal.SIGKILL)
    rc=close_wait('runner-kill',p,so,se)
    text=open(os.path.join(out,'runner-kill','stdout.log')).read()+open(os.path.join(out,'runner-kill','stderr.log')).read()
    if rc!=1 or ('status' not in text.lower() and 'signal' not in text.lower() and 'killed' not in text.lower()): fail.append('runner-kill')
    if os.path.exists(sp): fail.append('runner-kill session remains')
    # Foreground SIGINT plain, quiet and JSON: signal only this recorded Grantiva PID.
    for name,extra in [('sigint-plain',[]),('sigint-quiet',['--quiet']),('sigint-json',['--json'])]:
        p,so,se=start(name,extra); current=p; sp,sd=wait_session(p); write(name+'/session-ready.json',json.dumps(sd,indent=2)); os.kill(p.pid,signal.SIGINT)
        rc=close_wait(name,p,so,se)
        err=open(os.path.join(out,name,'stderr.log')).read()
        if rc!=130 or '[grantiva] received SIGINT — releasing emulator and reaping child processes' not in err: fail.append(name)
        if os.path.exists(sp): fail.append(name+' session remains')
    write('failures.json',json.dumps(fail,indent=2))
    sys.exit(0 if not fail else 1)
finally:
    if current is not None and current.poll() is None:
        subprocess.run([grantiva,'runner','stop','--json'],cwd=project,capture_output=True,text=True)
        try: current.wait(timeout=20)
        except subprocess.TimeoutExpired:
            current.send_signal(signal.SIGINT)
            current.wait(timeout=20)
