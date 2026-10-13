import json,os,signal,subprocess,sys,time
r,cwd,g,u,app,home=sys.argv[1:]
cmd=[g,'run','--app-file',app,'--simulator',u,'--flow','.maestro/11-slow.yaml']
open(r+'/run.command.json','w').write(json.dumps(cmd,indent=2)+'\n')
out=open(r+'/run.out','wb'); err=open(r+'/run.err','wb')
p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
open(r+'/run.pid','w').write(str(p.pid)+'\n')
lock=home+'/locks/'+u+'.lock'; deadline=time.monotonic()+30
while time.monotonic()<deadline and p.poll() is None:
 if os.path.exists(lock):
  try:
   claim=json.load(open(lock))
   if claim.get('pid')==p.pid and len(claim.get('temporaryDirectories',[]))>=2: break
  except Exception: pass
 time.sleep(.05)
else: raise SystemExit('owned claim with two temp dirs not observed while run alive')
open(r+'/claim-before-kill.json','w').write(json.dumps(claim,indent=2)+'\n')
for x in claim['temporaryDirectories']:
 if not os.path.exists(x): raise SystemExit('claimed temp missing '+x)
os.kill(p.pid,signal.SIGKILL); rc=p.wait(timeout=15); out.close(); err.close()
open(r+'/run.exit','w').write(str(rc)+'\n')
