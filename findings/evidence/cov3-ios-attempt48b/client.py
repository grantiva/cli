import glob,json,os,signal,subprocess,sys,time
root,cwd,g,u=sys.argv[1:]
cases=[]
def save(path,text):
    open(os.path.join(root,path),'w').write(text)
def state(stem,pid):
    items=[]
    for path in glob.glob('/tmp/grantiva-sessions/*'):
        try: items.append({'path':path,'text':open(path).read()})
        except Exception as exc: items.append({'path':path,'error':str(exc)})
    json.dump(items,open(os.path.join(root,stem+'-sessions.json'),'w'),indent=2)
    r=subprocess.run(['ps','-axo','pid,ppid,state,etime,command'],capture_output=True,text=True)
    save(stem+'-ps.txt',r.stdout)
    save(stem+'-target-ps.txt','\n'.join(x for x in r.stdout.splitlines() if str(pid) in x)+'\n')
def ready_copy(name,suffix,ready):
    if os.path.exists(ready): save(name+'.ready-'+suffix,open(ready).read())
    else: save(name+'.ready-'+suffix+'.absent','absent\n')
def run_case(name,flow,release,terminal=None,json_mode=False):
    ready=os.path.join(root,name+'.ready')
    cmd=[g,'run','--no-build','--simulator',u,'--flow',flow,'--keep-alive','--ready-file',ready]
    if json_mode: cmd.append('--json')
    save(name+'.command.json',json.dumps(cmd)+'\n')
    out=open(os.path.join(root,name+'.out'),'w'); err=open(os.path.join(root,name+'.err'),'w')
    p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
    save(name+'.pid',str(p.pid)+'\n')
    observed=None
    for n in range(900):
        if terminal:
            if os.path.exists(ready):
                try:
                    data=json.load(open(ready))
                    if data.get('status')==terminal: observed={'source':'ready','data':data}; break
                except Exception: pass
        else:
            err.flush()
            text=open(os.path.join(root,name+'.err')).read()
            if '[1/1]' in text and 'launchApp' in text:
                observed={'source':'runner-stream','matched':'[1/1] and launchApp'}; break
        if p.poll() is not None: break
        time.sleep(.1)
    json.dump({'polls':n+1,'childPoll':p.poll(),'observation':observed},open(os.path.join(root,name+'.observation.json'),'w'),indent=2)
    if observed is None: raise RuntimeError(name+' did not reach requested state')
    ready_copy(name,'before-release',ready); state(name+'-before-release',p.pid)
    stop=None
    if release=='stop':
        stop=subprocess.Popen([g,'runner','stop','--json'],cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    else:
        os.killpg(p.pid,signal.SIGINT)
    deadline=time.monotonic()+40
    polls=[]
    while time.monotonic()<deadline:
        rc=p.poll()
        polls.append({'elapsed':round(40-(deadline-time.monotonic()),3),'childPoll':rc,'stopPoll':None if stop is None else stop.poll()})
        if rc is not None and (stop is None or stop.poll() is not None): break
        time.sleep(.1)
    json.dump(polls,open(os.path.join(root,name+'.release-polls.json'),'w'),indent=2)
    if p.poll() is None:
        os.killpg(p.pid,signal.SIGTERM)
    rc=p.wait(timeout=10)
    if stop is not None:
        so,se=stop.communicate(timeout=10); save(name+'.stop.out',so); save(name+'.stop.err',se); save(name+'.stop.exit.txt',str(stop.returncode)+'\n')
    out.close(); err.close(); save(name+'.exit.txt',str(rc)+'\n')
    ready_copy(name,'final',ready); state(name+'-after-release',p.pid)
    final=json.load(open(ready)) if os.path.exists(ready) else None
    cases.append({'name':name,'release':release,'exit':rc,'observation':observed,'final':final})
try:
    for i in range(1,4): run_case('slow-stop-'+str(i),'.maestro/coverage/18-long-wait.yaml','stop')
    run_case('pass-stop','.maestro/01-browse.yaml','stop',terminal='passed')
    run_case('fail-stop','.maestro/coverage/02-exact-negative.yaml','stop',terminal='failed')
    run_case('pass-sigint','.maestro/01-browse.yaml','sigint',terminal='passed',json_mode=True)
    run_case('fail-sigint','.maestro/coverage/02-exact-negative.yaml','sigint',terminal='failed',json_mode=True)
finally:
    r=subprocess.run([g,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True,timeout=40)
    save('final-stop.out',r.stdout); save('final-stop.err',r.stderr); save('final-stop.exit.txt',str(r.returncode)+'\n')
json.dump(cases,open(os.path.join(root,'case-summary.json'),'w'),indent=2)
