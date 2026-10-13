import glob,json,os,subprocess,sys,threading,time
root,a,b,g,u=sys.argv[1:]; active=None
def write(stem,suf,data):
 with open(f'{root}/{stem}.{suf}','w') as f:f.write(data)
def stop(stem,cwd,jsonmode=False):
 cmd=[g,'runner','stop']+(['--json'] if jsonmode else []);r=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,timeout=30);write(stem,'out',r.stdout);write(stem,'err',r.stderr);write(stem,'exit',str(r.returncode)+'\n');return r
def start(stem,cwd):
 global active
 out=open(f'{root}/{stem}.run.out','w');err=open(f'{root}/{stem}.run.err','w');ready=f'{root}/{stem}.ready';cmd=[g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--ready-file',ready]
 write(stem,'command.json',json.dumps(cmd,indent=2)+'\n');p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True);res={};t=threading.Thread(target=lambda:res.update(rc=p.wait()));t.start();active=(stem,cwd,p,t,res,out,err,ready);write(stem,'pid',str(p.pid)+'\n')
 end=time.monotonic()+90
 while time.monotonic()<end:
  try:d=json.load(open(ready))
  except:d=None
  if d and d.get('status')=='passed':
   write(stem,'ready-before.json',json.dumps(d,indent=2)+'\n');write(stem,'sidecars-before.txt','\n'.join(glob.glob('/tmp/grantiva-sessions/*'))+'\n');write(stem,'lock-before.txt',str(os.path.exists(os.environ['GRANTIVA_RUNNER_HOME']+'/locks/'+u+'.lock'))+'\n');return p,t,res,out,err,ready
  if not t.is_alive():raise RuntimeError(f'{stem} exited before passed')
  time.sleep(.1)
 raise RuntimeError(f'{stem} not ready')
def finish(stem,x):
 global active
 p,t,res,out,err,ready=x;t.join(30)
 if t.is_alive():p.kill();t.join(10)
 out.close();err.close();write(stem,'run.exit',str(res.get('rc',p.returncode))+'\n');write(stem,'ready-after.json',open(ready).read());write(stem,'sidecars-after.txt','\n'.join(glob.glob('/tmp/grantiva-sessions/*'))+'\n');write(stem,'lock-after.txt',str(os.path.exists(os.environ['GRANTIVA_RUNNER_HOME']+'/locks/'+u+'.lock'))+'\n');active=None
try:
 x=start('same-text',a);stop('same-text.stop',a);finish('same-text',x)
 x=start('same-json',a);stop('same-json.stop',a,True);finish('same-json',x)
 x=start('other-control',a);stop('other-dir.stop',b,True);write('other-control','alive-after-other',str(x[0].poll() is None)+'\n')
 h=subprocess.run([g,'hierarchy','--udid',u,'--format','json'],cwd=a,capture_output=True,text=True,timeout=15);write('other-control.hierarchy','out',h.stdout);write('other-control.hierarchy','err',h.stderr);write('other-control.hierarchy','exit',str(h.returncode)+'\n')
 stop('other-control.stop',a,True);finish('other-control',x)
 stop('none-text.stop',a);stop('none-json.stop',a,True)
finally:
 if active is not None:
  stem,cwd,p,t,res,out,err,ready=active
  try:stop('exception-cleanup.stop',cwd,True)
  except:pass
  t.join(30)
  if t.is_alive():p.kill();t.join(10)
  out.close();err.close()
