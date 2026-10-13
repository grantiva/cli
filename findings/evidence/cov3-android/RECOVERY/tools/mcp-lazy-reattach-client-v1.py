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
mcp=subprocess.Popen([grantiva,'mcp','--project-dir',cwd,'--platform','android'],cwd=cwd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=mcp_err,start_new_session=True)
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
runner,runner_out,runner_err=spawn([grantiva,'runner','start','--device',udid,'--application-id','com.kylebrowning.landmarks','--detach','--json'],'runner-foreground')
session=os.path.join(cwd,'.grantiva','session.json'); observations=[]; saw_starting=False
for i in range(100):
    state=None; data=None
    if os.path.exists(session):
        try: data=json.load(open(session)); state=data.get('state')
        except Exception: state='unreadable'
    observations.append({'poll':i,'elapsed':i*.1,'exists':os.path.exists(session),'state':state,'data':data})
    if state=='starting':
        saw_starting=True
        for name,args in [('second-json',[grantiva,'runner','start','--device',udid,'--application-id','com.kylebrowning.landmarks','--detach','--json']),('second-text',[grantiva,'runner','start','--device',udid,'--application-id','com.kylebrowning.landmarks','--detach']),('dump-starting',[grantiva,'runner','dump-hierarchy'])]:
            r=subprocess.run(args,cwd=cwd,capture_output=True,text=True,timeout=20)
            open(os.path.join(root,name+'.out'),'w').write(r.stdout); open(os.path.join(root,name+'.err'),'w').write(r.stderr); open(os.path.join(root,name+'.exit.txt'),'w').write(str(r.returncode)+'\n')
        for tool in ('grantiva_tap','grantiva_type','grantiva_swipe','grantiva_script','grantiva_a11y_tree','grantiva_a11y_check','grantiva_screenshot'):
            args=({'label':'No Such'} if tool=='grantiva_tap' else {'text':'x'} if tool=='grantiva_type' else {'direction':'up'} if tool=='grantiva_swipe' else {'steps':[{'wait':0.1}]} if tool=='grantiva_script' else {})
            rpc('tools/call',{'name':tool,'arguments':args},f'starting-{tool}')
        for uri in ('grantiva://hierarchy','grantiva://screenshot'):
            rpc('resources/read',{'uri':uri},'starting-resource-'+uri.split('//')[1])
        break
    time.sleep(.1)
json.dump({'sawStarting':saw_starting,'observations':observations},open(os.path.join(root,'starting-observations.json'),'w'),indent=2)
for i in range(150):
    try: state=json.load(open(session)).get('state')
    except Exception: state=None
    if state=='ready': break
    time.sleep(.1)
json.dump({'polls':i+1,'state':state,'runnerAlive':runner.poll() is None},open(os.path.join(root,'ready-observation.json'),'w'))
# The session file can say ready just before attachable app tools succeed. Keep
# the same MCP process and retry each ready control until it returns success.
def retry_ready(method,params,prefix):
    last=None
    for attempt in range(20):
        last=rpc(method,params,f'{prefix}-{attempt+1}',30)
        if last and 'error' not in last and isinstance(last.get('result'),dict) and not last['result'].get('isError',False):
            return {'attempts':attempt+1,'success':True}
        time.sleep(.25)
    return {'attempts':20,'success':False,'last':last}
ready_results={
 'tree':retry_ready('tools/call',{'name':'grantiva_a11y_tree','arguments':{}},'ready-tree'),
 'resourceHierarchy':retry_ready('resources/read',{'uri':'grantiva://hierarchy'},'ready-resource-hierarchy'),
 'resourceScreenshot':retry_ready('resources/read',{'uri':'grantiva://screenshot'},'ready-resource-screenshot'),
 'screenshot':retry_ready('tools/call',{'name':'grantiva_screenshot','arguments':{}},'ready-screenshot')}
json.dump(ready_results,open(os.path.join(root,'ready-results.json'),'w'),indent=2)
missing=rpc('tools/call',{'name':'grantiva_tap','arguments':{'label':'__round3_missing_label__'}},'ready-missing-label',30)
json.dump({'isError':bool(missing and missing.get('result',{}).get('isError')),'response':missing},open(os.path.join(root,'ready-missing-label-summary.json'),'w'),indent=2)
open(os.path.join(root,'first-detach-exit-before-stop.txt'),'w').write(str(runner.poll())+'\n')
stop=subprocess.run([grantiva,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True,timeout=30)
open(os.path.join(root,'stop.out'),'w').write(stop.stdout); open(os.path.join(root,'stop.err'),'w').write(stop.stderr); open(os.path.join(root,'stop.exit.txt'),'w').write(str(stop.returncode)+'\n')
try: rrc=runner.wait(timeout=30)
except subprocess.TimeoutExpired: runner.terminate(); rrc=runner.wait(timeout=10)
runner_out.close(); runner_err.close(); open(os.path.join(root,'runner-foreground.exit.txt'),'w').write(str(rrc)+'\n')
# Replace the stopped session while keeping this exact MCP server alive.
runner2,runner2_out,runner2_err=spawn([grantiva,'runner','start','--device',udid,'--application-id','com.kylebrowning.landmarks','--detach','--json'],'replacement-runner')
replacement_ready=None
for attempt in range(150):
    replacement_ready=rpc('tools/call',{'name':'grantiva_a11y_tree','arguments':{}},f'replacement-tree-{attempt+1}',30)
    if replacement_ready and 'error' not in replacement_ready and not replacement_ready.get('result',{}).get('isError',False): break
    time.sleep(.1)
json.dump({'attempts':attempt+1,'success':bool(replacement_ready and 'error' not in replacement_ready and not replacement_ready.get('result',{}).get('isError',False))},open(os.path.join(root,'replacement-summary.json'),'w'),indent=2)
stop2=subprocess.run([grantiva,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True,timeout=30)
open(os.path.join(root,'replacement-stop.out'),'w').write(stop2.stdout); open(os.path.join(root,'replacement-stop.err'),'w').write(stop2.stderr); open(os.path.join(root,'replacement-stop.exit.txt'),'w').write(str(stop2.returncode)+'\n')
try: rr2=runner2.wait(timeout=30)
except subprocess.TimeoutExpired: runner2.terminate(); rr2=runner2.wait(timeout=10)
runner2_out.close(); runner2_err.close(); open(os.path.join(root,'replacement-runner.exit.txt'),'w').write(str(rr2)+'\n')
mcp.stdin.close()
try: mcp.wait(timeout=10)
except subprocess.TimeoutExpired: mcp.kill(); mcp.wait()
mcp_err.close(); raw.close(); open(os.path.join(root,'mcp-server.exit.txt'),'w').write(str(mcp.returncode)+'\n')
