import glob,json,os,pathlib,subprocess,sys,threading,time
out,project,other,grantiva,serial=sys.argv[1:]; R=pathlib.Path(out); R.mkdir(parents=True)
argv=[grantiva,'runner','start','--platform','android','--device',serial,'--application-id','com.kylebrowning.landmarks']
(R/'start-command.json').write_text(json.dumps(argv)+'\n'); so=open(R/'start.out','w'); se=open(R/'start.err','w'); p=subprocess.Popen(argv,cwd=project,stdout=so,stderr=se,text=True); result={}
def reap(): result['rc']=p.wait()
waiter=threading.Thread(target=reap); waiter.start(); owner=None
try:
 for _ in range(1200):
  if p.poll() is not None: break
  for f in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
   try:d=json.load(open(f))
   except:continue
   if pathlib.Path(d.get('projectDirectory','')).resolve()==pathlib.Path(project).resolve() and d.get('udid')==serial and d.get('grantivaPid')==p.pid: owner=(f,d); break
  if owner: break
  time.sleep(.1)
 if not owner: raise RuntimeError('owned foreground sidecar missing')
 (R/'owner.json').write_text(json.dumps(owner[1],indent=2)+'\n'); rpid=owner[1]['runnerPid']; samples=[]; control={'stop':False}
 def poll():
  while not control['stop']:
   files=sorted(glob.glob(f'/tmp/grantiva-sessions/{rpid}*')); samples.append({'t':time.time(),'files':files})
   for f in files:
    if f.endswith('.stop.json'):
     try:(R/'observed-stop-marker.json').write_text(pathlib.Path(f).read_text())
     except OSError:pass
   time.sleep(.1)
 poller=threading.Thread(target=poll); poller.start(); t0=time.monotonic(); td=subprocess.run([grantiva,'emulator','teardown','--serial',serial,'--force','--json'],cwd=other,capture_output=True,text=True,timeout=90)
 (R/'teardown.json').write_text(td.stdout); (R/'teardown.err').write_text(td.stderr); waiter.join(timeout=45); control['stop']=True; poller.join(); so.close(); se.close(); (R/'start.exit.txt').write_text(str(result.get('rc'))+'\n'); (R/'marker-samples.json').write_text(json.dumps(samples,indent=2)+'\n')
 remaining=sorted(glob.glob(f'/tmp/grantiva-sessions/{rpid}*')); text=(R/'start.out').read_text()+(R/'start.err').read_text(); checks={'teardown0':td.returncode==0,'foreground0':result.get('rc')==0,'stoppedMessage':'Runner stopped by teardown' in text and 'session has ended' in text,'markerObserved':(R/'observed-stop-marker.json').exists(),'filesRemoved':not remaining,'runnerDead':subprocess.run(['kill','-0',str(rpid)],capture_output=True).returncode!=0,'elapsedBounded':time.monotonic()-t0<45}
 (R/'decoded.json').write_text(json.dumps({'checks':checks,'runnerPid':rpid},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
finally:
 if p.poll() is None: p.send_signal(2); waiter.join(timeout=20)
 so.close(); se.close()
