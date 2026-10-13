import json,os,signal,shutil,subprocess,sys,time
root,scratch,g,u=sys.argv[1:]; ready=root+'/keepalive.ready'
cmd=[g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--ready-file',ready]
open(root+'/keepalive.command.json','w').write(json.dumps(cmd)+'\n')
p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/keepalive.out','w'),stderr=open(root+'/keepalive.err','w'),start_new_session=True)
open(root+'/keepalive.pid','w').write(str(p.pid)+'\n')
for n in range(90):
 if os.path.exists(ready): break
 if p.poll() is not None: break
 time.sleep(1)
open(root+'/ready-observation.json','w').write(json.dumps({'exists':os.path.exists(ready),'polls':n+1,'processAlive':p.poll() is None})+'\n')
if os.path.exists(ready): shutil.copy2(ready,root+'/keepalive.ready-before-signal')
def run(name,args):
 cp=subprocess.run(args,cwd=scratch,capture_output=True,text=True)
 open(root+'/'+name+'.command.json','w').write(json.dumps(args)+'\n'); open(root+'/'+name+'.out','w').write(cp.stdout); open(root+'/'+name+'.err','w').write(cp.stderr); open(root+'/'+name+'.exit.txt','w').write(str(cp.returncode)+'\n')
run('hierarchy-xml',[g,'hierarchy','--udid',u])
run('hierarchy-format-json',[g,'hierarchy','--udid',u,'--format','json'])
run('hierarchy-json-alias',[g,'hierarchy','--udid',u,'--json'])
run('hierarchy-timeout',[g,'hierarchy','--udid',u,'--timeout','0.01'])
run('hierarchy-after-ready',[g,'hierarchy','--udid',u,'--format','json'])
open(root+'/pre-signal-ps.txt','w').write(subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],capture_output=True,text=True).stdout)
if p.poll() is None: os.killpg(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:
 os.killpg(p.pid,signal.SIGTERM)
 try:p.wait(timeout=5)
 except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGKILL); p.wait(timeout=5)
 rc=124
open(root+'/keepalive.exit.txt','w').write(str(rc)+'\n')
if os.path.exists(ready): shutil.copy2(ready,root+'/keepalive.ready-after-signal')
open(root+'/post-signal-ps.txt','w').write(subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],capture_output=True,text=True).stdout)
