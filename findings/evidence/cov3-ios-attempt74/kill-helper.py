import json,os,signal,subprocess,sys,time
root,cwd,g,u,app,home=sys.argv[1:]; report=root+'/preserved-report'; lock=home+'/locks/'+u+'.lock'
cmd=[g,'run','--app-file',app,'--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--ready-file',root+'/ready.json','--report-dir',report]
open(root+'/run.command.json','w').write(json.dumps(cmd,indent=2)+'\n')
out=open(root+'/run.out','wb');err=open(root+'/run.err','wb');p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
open(root+'/run.pid','w').write(str(p.pid)+'\n')
deadline=time.monotonic()+90
while time.monotonic()<deadline and p.poll() is None:
    if os.path.exists(root+'/ready.json'):
        try:
            if json.load(open(root+'/ready.json')).get('status')=='passed': break
        except Exception: pass
    time.sleep(.1)
else: raise SystemExit('run never reached passed keep-alive hold')
if not os.path.exists(lock): raise SystemExit('lease claim absent')
open(root+'/lock-before-kill.bin','wb').write(open(lock,'rb').read())
subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],stdout=open(root+'/ps-before-kill.txt','wb'))
os.kill(p.pid,signal.SIGKILL); rc=p.wait(timeout=15); out.close();err.close()
open(root+'/run.exit.txt','w').write(str(rc)+'\n')
time.sleep(2)
subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],stdout=open(root+'/ps-after-kill.txt','wb'))
