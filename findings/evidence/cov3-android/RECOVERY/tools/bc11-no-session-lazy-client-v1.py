import json, os, queue, subprocess, sys, threading, time

root, cwd, grantiva, serial = sys.argv[1:]
os.makedirs(root, exist_ok=True)
raw = open(os.path.join(root, 'mcp-stdout.raw'), 'w')
serr = open(os.path.join(root, 'mcp-server.err'), 'w')
mcp = subprocess.Popen([grantiva, 'mcp', '--project-dir', cwd, '--platform', 'android'], cwd=cwd,
                       stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=serr, start_new_session=True)
json.dump([grantiva, 'mcp', '--project-dir', cwd, '--platform', 'android'], open(os.path.join(root, 'mcp-command.json'), 'w'))
q = queue.Queue()
def reader():
    for b in mcp.stdout:
        s=b.decode(errors='replace'); raw.write(s); raw.flush(); q.put(s)
    q.put(None)
threading.Thread(target=reader, daemon=True).start()
seq=0
def rpc(method, params, stem, timeout=30):
    global seq
    seq += 1; req={'jsonrpc':'2.0','id':seq,'method':method,'params':params}; start=time.monotonic()
    mcp.stdin.write((json.dumps(req)+'\n').encode()); mcp.stdin.flush(); response=None
    while time.monotonic()-start < timeout:
        try: line=q.get(timeout=.1)
        except queue.Empty: continue
        if line is None: break
        try: obj=json.loads(line)
        except Exception: continue
        if obj.get('id')==seq: response=obj; break
    json.dump({'request':req,'response':response,'elapsedSeconds':time.monotonic()-start},open(os.path.join(root,stem+'.json'),'w'),indent=2)
    return response

rpc('initialize', {'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'round3-coverage','version':'1'}}, 'initialize')
tools={
 'tap':('grantiva_tap',{'label':'Landmarks'}), 'swipe':('grantiva_swipe',{'direction':'up'}),
 'type':('grantiva_type',{'text':'x'}), 'screenshot':('grantiva_screenshot',{}),
 'tree':('grantiva_a11y_tree',{}), 'check':('grantiva_a11y_check',{}),
 'script':('grantiva_script',{'steps':[{'wait':.1}]})}
no_session={}
for stem,(name,args) in tools.items():
    response=rpc('tools/call',{'name':name,'arguments':args},'no-session-'+stem)
    result=(response or {}).get('result',{})
    text=result.get('content',[{}])[0].get('text','') if result.get('content') else ''
    no_session[stem]={'isError':result.get('isError') is True,'hasNoActive':'No active runner session' in text,'hasStartRemedy':'Start one with' in text}
json.dump(no_session,open(os.path.join(root,'no-session-summary.json'),'w'),indent=2,sort_keys=True)

rout=open(os.path.join(root,'runner.out'),'w'); rerr=open(os.path.join(root,'runner.err'),'w')
cmd=[grantiva,'runner','start','--device',serial,'--application-id','com.kylebrowning.landmarks','--detach','--json']
json.dump(cmd,open(os.path.join(root,'runner-command.json'),'w'))
runner=subprocess.Popen(cmd,cwd=cwd,stdout=rout,stderr=rerr,start_new_session=True)
success=False
for attempt in range(60):
    response=rpc('tools/call',{'name':'grantiva_a11y_tree','arguments':{}},f'after-start-tree-{attempt+1}')
    result=(response or {}).get('result',{})
    if response and 'error' not in response and result.get('isError') is not True:
        success=True; break
    time.sleep(.25)
json.dump({'success':success,'attempts':attempt+1},open(os.path.join(root,'lazy-attach-summary.json'),'w'),indent=2)
stop=subprocess.run([grantiva,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True,timeout=30)
open(os.path.join(root,'stop.out'),'w').write(stop.stdout); open(os.path.join(root,'stop.err'),'w').write(stop.stderr)
open(os.path.join(root,'stop.exit.txt'),'w').write(str(stop.returncode)+'\n')
try: rrc=runner.wait(timeout=30)
except subprocess.TimeoutExpired: runner.terminate(); rrc=runner.wait(timeout=10)
rout.close(); rerr.close(); open(os.path.join(root,'runner.exit.txt'),'w').write(str(rrc)+'\n')
mcp.stdin.close()
try: mcp.wait(timeout=10)
except subprocess.TimeoutExpired: mcp.kill(); mcp.wait()
raw.close(); serr.close(); open(os.path.join(root,'mcp.exit.txt'),'w').write(str(mcp.returncode)+'\n')
ok=all(all(v.values()) for v in no_session.values()) and success and stop.returncode==0 and rrc==0 and mcp.returncode==0
raise SystemExit(0 if ok else 1)
