import json,os,signal,subprocess,sys,time,glob
root,cwd,g,u=sys.argv[1:]
cases=[]
def snapshot(stem):
    files=[]
    for p in glob.glob('/tmp/grantiva-sessions/*'):
        try: files.append({'path':p,'text':open(p).read()})
        except Exception: files.append({'path':p,'text':'<unreadable>'})
    json.dump(files,open(os.path.join(root,stem+'-session-files.json'),'w'),indent=2)
def run_case(name,flow,release,json_mode=False,need_running=False):
    ready=os.path.join(root,name+'.ready'); cmd=[g,'run','--no-build','--simulator',u,'--flow',flow,'--keep-alive','--ready-file',ready]
    if json_mode: cmd.append('--json')
    open(os.path.join(root,name+'.command.json'),'w').write(json.dumps(cmd)+'\n')
    out=open(os.path.join(root,name+'.out'),'w'); err=open(os.path.join(root,name+'.err'),'w')
    p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
    open(os.path.join(root,name+'.pid'),'w').write(str(p.pid)+'\n')
    observed=None
    for n in range(500):
        if os.path.exists(ready):
            try:
                data=json.load(open(ready)); status=data.get('status'); fs=[x.get('status') for x in data.get('flows',[])]
                if (need_running and ('running' in fs or status=='running')) or (not need_running and status in ('passed','failed')):
                    observed=data; break
            except Exception: pass
        if p.poll() is not None: break
        time.sleep(.1)
    json.dump({'polls':n+1,'alive':p.poll() is None,'ready':observed},open(os.path.join(root,name+'.observation.json'),'w'),indent=2)
    if observed is None: raise RuntimeError(name+' did not reach requested ready state')
    snapshot(name+'-before-release')
    if release=='stop':
        r=subprocess.run([g,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True,timeout=30)
        open(os.path.join(root,name+'.stop.out'),'w').write(r.stdout); open(os.path.join(root,name+'.stop.err'),'w').write(r.stderr); open(os.path.join(root,name+'.stop.exit.txt'),'w').write(str(r.returncode)+'\n')
    else:
        os.killpg(p.pid,signal.SIGINT)
    try: rc=p.wait(timeout=30)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid,signal.SIGTERM); rc=p.wait(timeout=10)
    out.close(); err.close(); open(os.path.join(root,name+'.exit.txt'),'w').write(str(rc)+'\n')
    if os.path.exists(ready): open(os.path.join(root,name+'.ready-final'),'w').write(open(ready).read())
    snapshot(name+'-after-release')
    cases.append({'name':name,'release':release,'exit':rc,'initial':observed,'final':json.load(open(ready)) if os.path.exists(ready) else None})
try:
    for i in range(1,4): run_case('slow-stop-'+str(i),'.maestro/coverage/18-long-wait.yaml','stop',need_running=True)
    run_case('pass-stop','.maestro/01-browse.yaml','stop')
    run_case('fail-stop','.maestro/coverage/02-exact-negative.yaml','stop')
    run_case('pass-sigint','.maestro/01-browse.yaml','sigint',json_mode=True)
    run_case('fail-sigint','.maestro/coverage/02-exact-negative.yaml','sigint',json_mode=True)
finally:
    r=subprocess.run([g,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True)
    open(os.path.join(root,'final-stop.out'),'w').write(r.stdout); open(os.path.join(root,'final-stop.err'),'w').write(r.stderr); open(os.path.join(root,'final-stop.exit.txt'),'w').write(str(r.returncode)+'\n')
json.dump(cases,open(os.path.join(root,'case-summary.json'),'w'),indent=2)
