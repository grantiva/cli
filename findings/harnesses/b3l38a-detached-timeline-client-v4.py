#!/usr/bin/env python3
import json, os, queue, subprocess, sys, threading, time

out, project, grantiva, serial = sys.argv[1:]; os.makedirs(out, exist_ok=False)
session=os.path.join(project,'.grantiva','session.json'); stop=threading.Event(); lock=threading.Lock(); samples=[]
start=time.monotonic()
def read_session():
    try:
        with open(session) as f: return json.load(f)
    except Exception: return None
def sampler():
    n=0
    while not stop.is_set():
        target=start+n*.1; delay=target-time.monotonic()
        if delay>0: stop.wait(delay)
        if stop.is_set(): break
        now=time.monotonic()
        with lock: samples.append({'n':n,'targetElapsed':n*.1,'elapsed':now-start,'jitterMs':(now-target)*1000,'session':read_session()})
        n+=1
threading.Thread(target=sampler,daemon=True).start()

merr=open(os.path.join(out,'mcp.stderr.raw'),'w'); mout=open(os.path.join(out,'mcp.stdout.raw'),'w'); mq=queue.Queue(); pending={}; seq=0; reader_errors=[]; requests=[]
mcp=subprocess.Popen([grantiva,'mcp','--project-dir',project,'--platform','android'],cwd=project,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=merr,text=True,bufsize=1)
def reader():
    try:
        for line in mcp.stdout:
            mout.write(line); mout.flush()
            try: obj=json.loads(line)
            except Exception as exc:
                reader_errors.append({'line':line,'error':repr(exc)}); continue
            mq.put(obj)
    except Exception as exc:
        reader_errors.append({'readerException':repr(exc)})
threading.Thread(target=reader,daemon=True).start()
def send(method,params,stem):
    global seq
    seq+=1; req={'jsonrpc':'2.0','id':seq,'method':method,'params':params}; state=read_session(); t=time.monotonic()-start
    pending[seq]={'stem':stem,'request':req,'submittedElapsed':t,'sessionAtSubmit':state}; requests.append(req)
    mcp.stdin.write(json.dumps(req,separators=(',',':'))+'\n'); mcp.stdin.flush(); return seq
def collect(ids,timeout=30):
    end=time.monotonic()+timeout; left=set(ids)
    while left and time.monotonic()<end:
        try: obj=mq.get(timeout=.05)
        except queue.Empty: continue
        i=obj.get('id')
        if i in left:
            rec=pending[i]; rec['responseElapsed']=time.monotonic()-start; rec['sessionAtResponse']=read_session(); rec['response']=obj
            with open(os.path.join(out,rec['stem']+'.json'),'w') as f: json.dump(rec,f,indent=2)
            left.remove(i)
    if left:
        json.dump({'missingIds':sorted(left),'pending':{str(i):pending[i] for i in sorted(left)},'readerErrors':reader_errors},open(os.path.join(out,'missing-responses.json'),'w'),indent=2)
    return not left
init=send('initialize',{},'initialize')
if not collect([init],10): raise SystemExit(75)
initialized={'jsonrpc':'2.0','method':'notifications/initialized','params':{}}
requests.append(initialized); mcp.stdin.write(json.dumps(initialized,separators=(',',':'))+'\n'); mcp.stdin.flush()

so=open(os.path.join(out,'start.out'),'w'); se=open(os.path.join(out,'start.err'),'w')
cmd=[grantiva,'runner','start','--platform','android','--device',serial,'--application-id','com.kylebrowning.landmarks','--detach','--json','--verbose']
json.dump(cmd,open(os.path.join(out,'start.command.json'),'w')); p=subprocess.Popen(cmd,cwd=project,stdout=so,stderr=se)
probe_ids=[]; dump_thread=None
deadline=time.monotonic()+30
while time.monotonic()<deadline:
    state=read_session()
    if state and state.get('state')=='starting' and not probe_ids:
        probe_ids=[send('resources/read',{'uri':'grantiva://hierarchy'},'starting-resource'),send('tools/call',{'name':'grantiva_a11y_tree','arguments':{}},'starting-tool')]
        def dump():
            submitted=time.monotonic()-start; at_submit=read_session()
            d=subprocess.run([grantiva,'runner','dump-hierarchy'],cwd=project,capture_output=True,text=True,timeout=15)
            json.dump({'submittedElapsed':submitted,'sessionAtSubmit':at_submit,'responseElapsed':time.monotonic()-start,'sessionAtResponse':read_session(),'exit':d.returncode,'stdout':d.stdout,'stderr':d.stderr},open(os.path.join(out,'starting-dump.json'),'w'),indent=2)
        dump_thread=threading.Thread(target=dump); dump_thread.start()
    if state and state.get('state')=='ready': break
    time.sleep(.01)
rc=p.wait(timeout=30); so.close(); se.close()
if not probe_ids or not collect(probe_ids,30): raise SystemExit(76)
if dump_thread: dump_thread.join(20)
def ready_dump():
    submitted=time.monotonic()-start; at_submit=read_session()
    d=subprocess.run([grantiva,'runner','dump-hierarchy'],cwd=project,capture_output=True,text=True,timeout=30)
    json.dump({'submittedElapsed':submitted,'sessionAtSubmit':at_submit,'responseElapsed':time.monotonic()-start,'sessionAtResponse':read_session(),'exit':d.returncode,'stdout':d.stdout,'stderr':d.stderr},open(os.path.join(out,'ready-dump.json'),'w'),indent=2)
ready_dump_thread=threading.Thread(target=ready_dump); ready_dump_thread.start()
ready_resource=send('resources/read',{'uri':'grantiva://hierarchy'},'ready-resource')
if not collect([ready_resource],30): raise SystemExit(77)
ready_tool=send('tools/call',{'name':'grantiva_a11y_tree','arguments':{}},'ready-tool')
if not collect([ready_tool],30): raise SystemExit(77)
ready_dump_thread.join(35)
if ready_dump_thread.is_alive(): raise SystemExit(78)
stop.set(); time.sleep(.12)
with lock: frozen=list(samples)
json.dump(frozen,open(os.path.join(out,'timeline.json'),'w'),indent=2)
intervals=[(b['elapsed']-a['elapsed'])*1000 for a,b in zip(frozen,frozen[1:])]
states=[(x.get('session') or {}).get('state') for x in frozen]
json.dump({'startExit0':rc==0,'sampleCount':len(frozen),'maxIntervalMs':max(intervals) if intervals else None,'cadenceAtMost150ms':bool(intervals) and max(intervals)<=150,'startingSamples':states.count('starting'),'readySamples':states.count('ready'),'probeSubmittedWhileStarting':all((pending[i].get('sessionAtSubmit') or {}).get('state')=='starting' for i in probe_ids)},open(os.path.join(out,'cadence.json'),'w'),indent=2)
st=subprocess.run([grantiva,'runner','stop','--json'],cwd=project,capture_output=True,text=True,timeout=30); open(os.path.join(out,'stop.json'),'w').write(st.stdout); open(os.path.join(out,'stop.err'),'w').write(st.stderr)
json.dump(requests,open(os.path.join(out,'mcp.requests.json'),'w'),indent=2)
json.dump(reader_errors,open(os.path.join(out,'reader-errors.json'),'w'),indent=2)
mcp.stdin.close(); mcp.wait(timeout=10); merr.close(); mout.close()
required=['initialize','starting-resource','starting-tool','ready-resource','ready-tool']
missing=[stem for stem in required if not os.path.exists(os.path.join(out,stem+'.json'))]
json.dump({'required':required,'missing':missing,'mcpExit':mcp.returncode,'readerErrors':reader_errors},open(os.path.join(out,'response-audit.json'),'w'),indent=2)
raise SystemExit(0 if rc==0 and st.returncode==0 and mcp.returncode==0 and not missing and not reader_errors else 1)
