import json, subprocess, sys, time, os, threading, queue, re
# startprobe.py <projdir> <outdir>: MCP server up; spawn `runner start --detach` in background; every ~0.3 s
# resources/read hierarchy + screenshot and grantiva_a11y_tree until the start command exits and 3 good rounds pass.
proj, out = sys.argv[1], sys.argv[2]; G = os.environ['GRANTIVA']; os.makedirs(out, exist_ok=True)
log = open(os.path.join(out, 'transcript.txt'), 'w')
p = subprocess.Popen([G, 'mcp', '--project-dir', proj], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(os.path.join(out, 'server.stderr'), 'w'), cwd=proj)
q = queue.Queue(); threading.Thread(target=lambda: [q.put(l) for l in p.stdout], daemon=True).start()
nid=[0]; T0=time.time()
def call(method, params=None, tmo=60):
    nid[0]+=1; i=nid[0]; m={"jsonrpc":"2.0","id":i,"method":method}
    if params is not None: m["params"]=params
    p.stdin.write((json.dumps(m)+"\n").encode()); p.stdin.flush(); t0=time.time()
    while time.time()-t0<tmo:
        try: l=q.get(timeout=1)
        except queue.Empty: continue
        o=json.loads(l)
        if o.get("id")==i:
            s=re.sub(r'"(data|blob)": "[^"]{60}[^"]*"', r'"\1": "<b64>"', json.dumps(o))
            log.write("[%.2f] >> %s %s\n<< %s\n" % (time.time()-T0, method, json.dumps(params)[:70], s[:300])); log.flush(); return o
    log.write("NO RESPONSE %s\n"%method); return None
call("initialize", {"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}})
p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n'); p.stdin.flush()
st=subprocess.Popen([G,'runner','start','--detach'], cwd=proj, stdout=open(os.path.join(out,'start.out'),'w'), stderr=open(os.path.join(out,'start.err'),'w'))
log.write("[%.2f] spawned runner start --detach pid %d\n"%(time.time()-T0, st.pid))
good=0
while time.time()-T0<120:
    a=call("resources/read",{"uri":"grantiva://hierarchy"}); b=call("resources/read",{"uri":"grantiva://screenshot"}); c=call("tools/call",{"name":"grantiva_a11y_tree","arguments":{}})
    rc=st.poll()
    if rc is not None and not log.closed and 'start_exit' not in globals(): globals()['start_exit']=1; log.write("[%.2f] runner start exited rc=%s\n"%(time.time()-T0,rc))
    ok = a and 'result' in a and b and 'result' in b and c and 'result' in c and not c['result'].get('isError')
    good = good+1 if (ok and rc is not None) else 0
    if good>=3: break
    time.sleep(0.3)
p.stdin.close(); p.wait(timeout=20); log.write("server exit %s\n"%p.returncode)
