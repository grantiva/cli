import glob,json,os,queue,shutil,subprocess,sys,threading,time
root,cwd,g,u=sys.argv[1:]; os.makedirs(root,exist_ok=True)
raw=open(root+'/mcp.raw','w'); err=open(root+'/mcp.err','w'); q=queue.Queue()
m=subprocess.Popen([g,'mcp','--project-dir',cwd,'--platform','ios'],cwd=cwd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err)
def rd():
 for b in m.stdout:
  s=b.decode(errors='replace');raw.write(s);raw.flush();q.put(s)
 q.put(None)
threading.Thread(target=rd,daemon=True).start(); seq=0
def rpc(method,params,stem,timeout=8):
 global seq;seq+=1;req={'jsonrpc':'2.0','id':seq,'method':method,'params':params};t=time.monotonic();m.stdin.write((json.dumps(req)+'\n').encode());m.stdin.flush();got=None
 while time.monotonic()-t<timeout:
  try:s=q.get(timeout=.03)
  except queue.Empty:continue
  if s is None:break
  try:o=json.loads(s)
  except:continue
  if o.get('id')==seq:got=o;break
 json.dump({'elapsed':time.monotonic()-t,'request':req,'response':got},open(root+'/'+stem+'.json','w'),indent=2);return got
rpc('initialize',{},'initialize')
runout=open(root+'/run.out','w');runerr=open(root+'/run.err','w')
p=subprocess.Popen([g,'runner','start','--detach','--json','--simulator',u,'--bundle-id','com.kylebrowning.Landmarks','--platform','ios'],cwd=cwd,stdout=runout,stderr=runerr,start_new_session=True)
open(root+'/run.pid','w').write(str(p.pid)+'\n')
wait_result={}
def wait_run(): wait_result['rc']=p.wait()
wait_thread=threading.Thread(target=wait_run);wait_thread.start()
obs=[]; owner_path=None; owner_data=None
for i in range(200):
 matches=[]
 for path in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
  try:d=json.load(open(path))
  except:continue
  if d.get('grantivaPid')==p.pid and d.get('udid')==u and os.path.realpath(d.get('projectDirectory',''))==os.path.realpath(cwd): matches.append((path,d))
 
 try: session_data=json.load(open(cwd+'/.grantiva/session.json'))
 except: session_data=None
 obs.append({'i':i,'elapsed':i*.05,'ownerMatches':[x[0] for x in matches],'session':session_data,'projectFiles':glob.glob(cwd+'/.grantiva/*'),'globalFiles':glob.glob('/tmp/grantiva-sessions/*')})
 if len(matches)==1: owner_path,owner_data=matches[0];break
 time.sleep(.05)
json.dump({'ownerObserved':owner_path is not None,'ownerPath':owner_path,'owner':owner_data,'observations':obs},open(root+'/starting-observations.json','w'),indent=2)
if owner_path: shutil.copyfile(owner_path,root+'/owner-at-starting.json')
else: sys.exit(2)
for stem,cmd in [('starting-hierarchy',[g,'hierarchy','--udid',u,'--format','json']),('starting-dump',[g,'runner','dump-hierarchy','--format','json'])]:
 r=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,timeout=8);open(root+'/'+stem+'.out','w').write(r.stdout);open(root+'/'+stem+'.err','w').write(r.stderr);open(root+'/'+stem+'.exit','w').write(str(r.returncode)+'\n')
tools=[('tap',{'label':'Landmarks'}),('swipe',{'direction':'up'}),('type',{'text':'x'}),('screenshot',{}),('a11y_tree',{}),('a11y_check',{}),('script',{'steps':[{'tap':'Landmarks'}]})]
for n,a in tools:rpc('tools/call',{'name':'grantiva_'+n,'arguments':a},'starting-'+n,3)
rpc('resources/read',{'uri':'grantiva://hierarchy'},'starting-resource-hierarchy',3);rpc('resources/read',{'uri':'grantiva://screenshot'},'starting-resource-screenshot',3)
ready=False
for i in range(80):
 r=subprocess.run([g,'hierarchy','--udid',u,'--format','json'],cwd=cwd,capture_output=True,text=True)
 open(f'{root}/readiness-{i+1}.out','w').write(r.stdout);open(f'{root}/readiness-{i+1}.err','w').write(r.stderr);open(f'{root}/readiness-{i+1}.exit','w').write(str(r.returncode)+'\n')
 if r.returncode==0 and 'Landmarks' in r.stdout:ready=True;break
 time.sleep(.25)
json.dump({'ready':ready,'polls':i+1,'starterExit':p.poll()},open(root+'/readiness.json','w'),indent=2)
for stem,cmd in [('ready-hierarchy',[g,'hierarchy','--udid',u,'--format','json']),('ready-dump',[g,'runner','dump-hierarchy','--format','json'])]:
 r=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,timeout=15);open(root+'/'+stem+'.out','w').write(r.stdout);open(root+'/'+stem+'.err','w').write(r.stderr);open(root+'/'+stem+'.exit','w').write(str(r.returncode)+'\n')
for n,a in tools:rpc('tools/call',{'name':'grantiva_'+n,'arguments':a},'ready-'+n,15)
rpc('resources/read',{'uri':'grantiva://hierarchy'},'ready-resource-hierarchy',15);rpc('resources/read',{'uri':'grantiva://screenshot'},'ready-resource-screenshot',15)
stop=subprocess.run([g,'runner','stop','--json'],cwd=cwd,capture_output=True,text=True,timeout=30);open(root+'/stop.out','w').write(stop.stdout);open(root+'/stop.err','w').write(stop.stderr);open(root+'/stop.exit','w').write(str(stop.returncode)+'\n')
wait_thread.join(timeout=30)
if wait_thread.is_alive(): p.kill(); wait_thread.join(timeout=10)
rc=wait_result.get('rc',p.returncode)
open(root+'/run.exit','w').write(str(rc)+'\n');runout.close();runerr.close();m.stdin.close();m.wait(timeout=10);raw.close();err.close();sys.exit(0 if ready else 1)
