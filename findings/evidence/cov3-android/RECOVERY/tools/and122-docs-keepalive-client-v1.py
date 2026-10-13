import json, pathlib, subprocess, sys, threading, time

root, project, grantiva = sys.argv[1:]
R=pathlib.Path(root); R.mkdir(parents=True,exist_ok=True)
argv=[grantiva,'run','--keep-alive']; (R/'command-1.json').write_text(json.dumps(argv)+'\n')
so=open(R/'run.out','w'); se=open(R/'run.err','w'); p=subprocess.Popen(argv,cwd=project,stdout=so,stderr=se,text=True)
result={}
def reap(): result['rc']=p.wait()
t=threading.Thread(target=reap); t.start()
try:
 ready=False
 for attempt in range(1,181):
  if p.poll() is not None: break
  q=subprocess.run([grantiva,'hierarchy'],cwd=project,capture_output=True,text=True,timeout=20)
  (R/f'poll-{attempt}.out').write_text(q.stdout); (R/f'poll-{attempt}.err').write_text(q.stderr)
  if q.returncode==0 and '<hierarchy' in q.stdout: ready=True; break
  time.sleep(.5)
 if not ready: raise RuntimeError('documented keep-alive never served hierarchy')
 # Execute and preserve the two documented terminal-2 examples exactly as written.
 xml=subprocess.run([grantiva,'hierarchy'],cwd=project,capture_output=True,text=True,timeout=30)
 js=subprocess.run([grantiva,'hierarchy','--format','json'],cwd=project,capture_output=True,text=True,timeout=30)
 (R/'command-2.txt').write_text('grantiva hierarchy\n'); (R/'hierarchy.xml').write_text(xml.stdout); (R/'hierarchy-xml.err').write_text(xml.stderr); (R/'hierarchy-xml.exit.txt').write_text(f'{xml.returncode}\n')
 (R/'command-3.txt').write_text('grantiva hierarchy --format json\n'); (R/'hierarchy.json').write_text(js.stdout); (R/'hierarchy-json.err').write_text(js.stderr); (R/'hierarchy-json.exit.txt').write_text(f'{js.returncode}\n')
 parsed=json.loads(js.stdout) if js.returncode==0 else {}
 stop=subprocess.run([grantiva,'runner','stop','--json'],cwd=project,capture_output=True,text=True,timeout=30)
 (R/'cleanup-stop.json').write_text(stop.stdout); (R/'cleanup-stop.err').write_text(stop.stderr)
 t.join(timeout=30); so.close(); se.close()
 checks={'keepAliveHeld':result.get('rc')==0,'xml0':xml.returncode==0 and '<hierarchy' in xml.stdout,'json0':js.returncode==0 and isinstance(parsed.get('children'),list),'sameTreeHasLandmarks':'Landmarks' in xml.stdout and 'Landmarks' in js.stdout,'cleanup0':stop.returncode==0}
 (R/'decoded.json').write_text(json.dumps({'checks':checks},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
finally:
 if p.poll() is None: subprocess.run([grantiva,'runner','stop','--json'],cwd=project,capture_output=True,text=True)
 t.join(timeout=20); so.close(); se.close()
