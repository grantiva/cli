import json, os, queue, subprocess, sys, threading, time

root, cwd, grantiva, udid = sys.argv[1:]
os.makedirs(root, exist_ok=True)

def spawn(cmd, stem):
    out=open(os.path.join(root,stem+'.out'),'w'); err=open(os.path.join(root,stem+'.err'),'w')
    p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
    open(os.path.join(root,stem+'.command.json'),'w').write(json.dumps(cmd)+'\n')
    open(os.path.join(root,stem+'.pid'),'w').write(str(p.pid)+'\n')
    return p,out,err

q=queue.Queue(); raw=open(os.path.join(root,'mcp-stdout.raw'),'w')
mcp_err=open(os.path.join(root,'mcp-server.err'),'w')
mcp=subprocess.Popen([grantiva,'mcp','--project-dir',cwd,'--platform','ios'],cwd=cwd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=mcp_err,start_new_session=True)
open(os.path.join(root,'mcp-server.pid'),'w').write(str(mcp.pid)+'\n')
def read_mcp():
    for b in mcp.stdout:
        s=b.decode(errors='replace'); raw.write(s); raw.flush(); q.put(s)
    q.put(None)
threading.Thread(target=read_mcp,daemon=True).start()
seq=0
def rpc(method,params,stem,timeout=8):
    global seq
    seq+=1; req={'jsonrpc':'2.0','id':seq,'method':method,'params':params}; t=time.monotonic()
    mcp.stdin.write((json.dumps(req)+'\n').encode()); mcp.stdin.flush()
    got=None
    while time.monotonic()-t < timeout:
        try: line=q.get(timeout=.05)
        except queue.Empty: continue
        if line is None: break
        try: obj=json.loads(line)
        except Exception: continue
        if obj.get('id')==seq: got=obj; break
    json.dump({'elapsed':time.monotonic()-t,'request':req,'response':got},open(os.path.join(root,stem+'.json'),'w'),indent=2)
    return got

rpc('initialize',{},'initialize')
runner,runner_out,runner_err=spawn([grantiva,'runner','start','--simulator',udid,'--bundle-id','com.kylebrowning.Landmarks'],'runner-foreground')
session=os.path.join(cwd,'.grantiva','session.json'); observations=[]; saw_starting=False
for i in range(100):
    state=None; data=None
    if os.path.exists(session):
        try: data=json.load(open(session)); state=data.get('state')
        except Exception: state='unreadable'
    observations.append({'poll':i,'elapsed':i*.1,'exists':os.path.exists(session),'state':state,'data':data})
    if state=='starting':
        saw_starting=True
        for name,args in [('second-json',[grantiva,'runner','start','--simulator',udid,'--bundle-id','com.kylebrowning.Landmarks','--detach','--json']),('second-text',[grantiva,'runner','start','--simulator',udid,'--bundle-id','com.kylebrowning.Landmarks','--detach']),('dump-starting',[grantiva,'runner','dump-hierarchy'])]:
            r=subprocess.run(args,cwd=cwd,capture_output=True,text=True,timeout=20)
            open(os.path.join(root,name+'.out'),'w').write(r.stdout); open(os.path.join(root,name+'.err'),'w').write(r.stderr); open(os.path.join(root,name+'.exit.txt'),'w').write(str(r.returncode)+'\n')
        for tool in ('grantiva_tap','grantiva_a11y_tree','grantiva_screenshot'):
            args={'label':'x'} if tool=='grantiva_tap' else {}
            rpc('tools/call',{'name':tool,'arguments':args},f'starting-{tool}')
        for uri in ('grantiva://hierarchy','grantiva://screenshot'):
            rpc('resources/read',{'uri':uri},'starting-resource-'+uri.split('//')[1])
        break
    if runner.poll() is not None: break
    time.sleep(.1)
json.dump({'sawStarting':saw_starting,'observations':observations},open(os.path.join(root,'starting-observations.json'),'w'),indent=2)
for i in range(150):
    try: state=json.load(open(session)).get('state')
    except Exception: state=None
    if state=='ready': break
    if runner.poll() is not None: break
    time.sleep(.1)
json.dump({'polls':i+1,'state':state,'runnerAlive':runner.poll() is None},open(os.path.join(root,'ready-observation.json'),'w'))
rpc('tools/call',{'name':'grantiva_a11y_tree','arguments':{}},'ready-tree',30)
rpc('resources/read',{'uri':'grantiva://hierarchy'},'ready-resource-hierarchy',30)
stop=subprocess.run([grantiva,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True,timeout=30)
open(os.path.join(root,'stop.out'),'w').write(stop.stdout); open(os.path.join(root,'stop.err'),'w').write(stop.stderr); open(os.path.join(root,'stop.exit.txt'),'w').write(str(stop.returncode)+'\n')
try: rrc=runner.wait(timeout=30)
except subprocess.TimeoutExpired: runner.terminate(); rrc=runner.wait(timeout=10)
runner_out.close(); runner_err.close(); open(os.path.join(root,'runner-foreground.exit.txt'),'w').write(str(rrc)+'\n')
mcp.stdin.close()
try: mcp.wait(timeout=10)
except subprocess.TimeoutExpired: mcp.kill(); mcp.wait()
mcp_err.close(); raw.close(); open(os.path.join(root,'mcp-server.exit.txt'),'w').write(str(mcp.returncode)+'\n')
