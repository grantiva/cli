import glob,json,os,pathlib,queue,subprocess,sys,threading,time
root,cwd,grantiva,serial=sys.argv[1:]; R=pathlib.Path(root); R.mkdir(parents=True,exist_ok=True)
def write(p,s): (R/p).write_text(s)
def cli(name,args,timeout=30):
 t=time.monotonic(); r=subprocess.run(args,cwd=cwd,capture_output=True,text=True,timeout=timeout); write(name+'.out',r.stdout); write(name+'.err',r.stderr); write(name+'.exit.txt',str(r.returncode)+'\n'); write(name+'.elapsed.txt',str(time.monotonic()-t)+'\n'); return r
# Start one MCP server before the run to exercise lazy shared-session discovery.
q=queue.Queue(); raw=open(R/'mcp.raw','w'); me=open(R/'mcp.err','w'); mcp=subprocess.Popen([grantiva,'mcp','--project-dir',cwd,'--platform','android'],cwd=cwd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=me)
def reader():
 for b in mcp.stdout:
  s=b.decode(errors='replace'); raw.write(s); raw.flush(); q.put(s)
 q.put(None)
threading.Thread(target=reader,daemon=True).start(); seq=0
def rpc(stem):
 global seq
 seq+=1; req={'jsonrpc':'2.0','id':seq,'method':'tools/call','params':{'name':'grantiva_a11y_tree','arguments':{}}}; t=time.monotonic(); mcp.stdin.write((json.dumps(req)+'\n').encode()); mcp.stdin.flush(); got=None
 while time.monotonic()-t<30:
  try: line=q.get(timeout=.05)
  except queue.Empty: continue
  if line is None: break
  try: o=json.loads(line)
  except Exception: continue
  if o.get('id')==seq: got=o; break
 json.dump({'elapsed':time.monotonic()-t,'request':req,'response':got},open(R/(stem+'.json'),'w'),indent=2); return got
rpc('initialize') if False else None
# Initialize explicitly.
seq+=1; req={'jsonrpc':'2.0','id':seq,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'l52','version':'1'}}}; mcp.stdin.write((json.dumps(req)+'\n').encode()); mcp.stdin.flush()
while True:
 line=q.get(timeout=10); o=json.loads(line)
 if o.get('id')==seq: json.dump(o,open(R/'initialize.json','w'),indent=2); break
mcp.stdin.write((json.dumps({'jsonrpc':'2.0','method':'notifications/initialized','params':{}})+'\n').encode()); mcp.stdin.flush()
ready=str(R/'ready.json'); report=str(R/'report')
out=open(R/'run.out','w'); err=open(R/'run.err','w'); argv=[grantiva,'run','--platform','android','--device',serial,'--no-build','--keep-alive','--flow','.maestro/slow-l52.yaml','--ready-file',ready,'--report-dir',report]; json.dump(argv,open(R/'run-command.json','w')); run=subprocess.Popen(argv,cwd=cwd,stdout=out,stderr=err,start_new_session=True); write('run.pid',str(run.pid)+'\n')
run_done=threading.Event(); run_result={}
def reap_run():
 run_result['rc']=run.wait(); write('run.exit.txt',str(run_result['rc'])+'\n'); run_done.set()
threading.Thread(target=reap_run,daemon=True).start()
# The shared owner sidecar is published before the project session/driver is ready.
owner=None
for n in range(300):
 for f in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
  try: x=json.load(open(f))
  except Exception: continue
  if x.get('grantivaPid')==run.pid and os.path.realpath(x.get('projectDirectory',''))==os.path.realpath(cwd): owner=(f,x); break
 if owner: break
 if run.poll() is not None: break
 time.sleep(.02)
json.dump({'found':bool(owner),'path':owner[0] if owner else None,'record':owner[1] if owner else None,'projectSessionExists':os.path.exists(os.path.join(cwd,'.grantiva/session.json'))},open(R/'owner-at-start.json','w'),indent=2)
# Fire both CLI surfaces concurrently, then the same-server MCP surface.
results={}
def call_cli(key,args): results[key]=cli('starting-'+key,args)
t1=threading.Thread(target=call_cli,args=('hierarchy',[grantiva,'hierarchy'])); t2=threading.Thread(target=call_cli,args=('dump',[grantiva,'runner','dump-hierarchy'])); t1.start(); t2.start(); starting_mcp=rpc('starting-mcp-tree'); t1.join(); t2.join()
# Retry all three surfaces until the driver is actually attachable while slow flow remains active.
def retry_cli(key,args,marker):
 for a in range(1,31):
  r=cli(f'ready-{key}-{a}',args)
  if r.returncode==0 and marker in r.stdout: return {'success':True,'attempts':a}
  time.sleep(.2)
 return {'success':False,'attempts':30}
def retry_mcp():
 for a in range(1,31):
  o=rpc(f'ready-mcp-{a}'); res=(o or {}).get('result',{})
  if o and 'error' not in o and not res.get('isError',False): return {'success':True,'attempts':a}
  time.sleep(.2)
 return {'success':False,'attempts':30}
ready_results={}
t1=threading.Thread(target=lambda:ready_results.update(hierarchy=retry_cli('hierarchy',[grantiva,'hierarchy'],'<hierarchy'))); t2=threading.Thread(target=lambda:ready_results.update(dump=retry_cli('dump',[grantiva,'runner','dump-hierarchy'],'[hierarchy]'))); t1.start(); t2.start(); ready_results['mcp']=retry_mcp(); t1.join(); t2.join(); json.dump(ready_results,open(R/'ready-results.json','w'),indent=2)
stop=cli('stop',[grantiva,'runner','stop','--json']);
if not run_done.wait(30): run.terminate(); run_done.wait(10)
if not run_done.is_set(): run.kill(); run_done.wait(5)
rrc=run_result.get('rc',run.poll()); out.close(); err.close()
mcp.stdin.close()
try:mcp.wait(timeout=10)
except subprocess.TimeoutExpired:mcp.kill();mcp.wait()
me.close();raw.close();write('mcp.exit.txt',str(mcp.returncode)+'\n')
# Decode exact starting wording and ready behavior.
def alltext(stem): return (R/(stem+'.out')).read_text()+(R/(stem+'.err')).read_text()
def mcptext(obj):
 try:return obj['result']['content'][0]['text']
 except:return ''
phrase='runner session is starting'; retry='retry in a few seconds'
checks={'ownerFoundBeforeProjectSession':bool(owner) and not json.load(open(R/'owner-at-start.json'))['projectSessionExists'],'hierarchyStarting':results['hierarchy'].returncode==1 and phrase in alltext('starting-hierarchy').lower() and retry in alltext('starting-hierarchy').lower() and 'no runner session' not in alltext('starting-hierarchy').lower(),'dumpStarting':results['dump'].returncode==1 and phrase in alltext('starting-dump').lower() and retry in alltext('starting-dump').lower() and 'no runner session' not in alltext('starting-dump').lower(),'mcpStarting':(starting_mcp or {}).get('result',{}).get('isError') is True and phrase in mcptext(starting_mcp).lower() and retry in mcptext(starting_mcp).lower(),'allReady':all(x['success'] for x in ready_results.values()),'stop0':stop.returncode==0,'runInterrupted':rrc==130}
json.dump({'checks':checks,'ready':ready_results},open(R/'decoded.json','w'),indent=2); print(json.dumps(checks,sort_keys=True)); sys.exit(0 if all(checks.values()) else 1)
