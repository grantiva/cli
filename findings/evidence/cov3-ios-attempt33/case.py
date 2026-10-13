import json,os,signal,subprocess,sys,time
root,scratch,g,u,name,flow,*envs=sys.argv[1:]
ready=root+'/'+name+'.ready'; cmd=[g,'run','--no-build','--simulator',u,'--flow',flow,'--keep-alive','--ready-file',ready]
for e in envs:cmd+=['--env',e]
open(root+'/'+name+'.command.json','w').write(json.dumps(cmd)+'\n')
p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/'+name+'.out','w'),stderr=open(root+'/'+name+'.err','w'),start_new_session=True)
for n in range(90):
 if os.path.exists(ready) or p.poll() is not None:break
 time.sleep(1)
open(root+'/'+name+'.observation.json','w').write(json.dumps({'ready':os.path.exists(ready),'alive':p.poll() is None,'polls':n+1})+'\n')
cp=subprocess.run([g,'hierarchy','--udid',u,'--format','json'],cwd=scratch,capture_output=True,text=True)
open(root+'/'+name+'.hierarchy.json','w').write(cp.stdout); open(root+'/'+name+'.hierarchy.err','w').write(cp.stderr); open(root+'/'+name+'.hierarchy.exit.txt','w').write(str(cp.returncode)+'\n')
if p.poll() is None:os.killpg(p.pid,signal.SIGINT)
try:rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=5);rc=124
open(root+'/'+name+'.exit.txt','w').write(str(rc)+'\n')
