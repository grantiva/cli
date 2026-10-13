import glob,json,os,pathlib,signal,subprocess,sys,time
r=pathlib.Path(sys.argv[1]); cwd=sys.argv[2]; g=sys.argv[3]; u=sys.argv[4]
def start(case):
 out=open(r/f'{case}.out','wb'); err=open(r/f'{case}.err','wb'); cmd=[g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--ready-file',str(r/f'{case}-ready.json')]
 p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True); deadline=time.monotonic()+90; owner=None
 while time.monotonic()<deadline and p.poll() is None:
  hits=[]
  for path in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
   try:
    x=json.load(open(path))
    if x.get('udid')==u and x.get('grantivaPid')==p.pid: hits.append((path,x))
   except Exception: pass
  if len(hits)==1 and (r/f'{case}-ready.json').exists():
   try:
    if json.load(open(r/f'{case}-ready.json')).get('status')=='passed': owner=hits[0]; break
   except Exception: pass
  time.sleep(.1)
 if owner is None: raise RuntimeError(case+' did not become ready with exact owner')
 opath,doc=owner; runner=int(doc['runnerPid']); sessions=sorted(glob.glob('/tmp/grantiva-sessions/'+str(runner)+'-*.grantiva'))
 if len(sessions)!=1: raise RuntimeError((case,sessions,doc))
 (r/f'{case}-owner.json').write_text(json.dumps(doc,indent=2)+'\n'); (r/f'{case}-runner.pid').write_text(str(runner)+'\n'); (r/f'{case}-session-path.txt').write_text(sessions[0]+'\n')
 return p,out,err,runner,opath,sessions[0]
p,out,err,runner,owner,session=start('first'); os.kill(runner,signal.SIGKILL); rc=p.wait(timeout=30); out.close(); err.close(); (r/'first-parent.exit').write_text(str(rc)+'\n'); time.sleep(.2)
(r/'first-sidecars-after.txt').write_text('\n'.join(glob.glob('/tmp/grantiva-sessions/'+str(runner)+'*'))+'\n')
if glob.glob('/tmp/grantiva-sessions/'+str(runner)+'*'): raise RuntimeError('first sidecars survived')
p,out,err,runner,owner,session=start('second'); session_bytes=open(session,'rb').read(); os.kill(p.pid,signal.SIGSTOP); os.kill(runner,signal.SIGKILL); os.kill(p.pid,signal.SIGCONT); os.kill(p.pid,signal.SIGINT); rc=p.wait(timeout=30); out.close(); err.close(); (r/'second-parent.exit').write_text(str(rc)+'\n')
deadline=time.monotonic()+5
while time.monotonic()<deadline and glob.glob('/tmp/grantiva-sessions/'+str(runner)+'*'): time.sleep(.05)
if glob.glob('/tmp/grantiva-sessions/'+str(runner)+'*'): raise RuntimeError('second cleanup incomplete')
open(session,'wb').write(session_bytes)
if os.path.exists(owner): raise RuntimeError('owner sidecar unexpectedly restored')
(r/'restored-stale-path.txt').write_text(session+'\n')
