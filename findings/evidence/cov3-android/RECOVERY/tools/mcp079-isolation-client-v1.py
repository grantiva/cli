import json, pathlib, subprocess, sys, threading, time
root,owner,other,grantiva,serial,mcp_client,request=sys.argv[1:]; R=pathlib.Path(root); R.mkdir(parents=True,exist_ok=True)
ready=R/'ready.json'; argv=[grantiva,'run','--platform','android','--device',serial,'--no-build','--keep-alive','--flow','.maestro/01-browse.yaml','--ready-file',str(ready),'--report-dir',str(R/'report')]
(R/'owner-command.json').write_text(json.dumps(argv)+'\n'); so=open(R/'owner.out','w'); se=open(R/'owner.err','w'); p=subprocess.Popen(argv,cwd=owner,stdout=so,stderr=se,text=True); result={}
def reap(): result['rc']=p.wait()
t=threading.Thread(target=reap); t.start()
try:
 end=time.monotonic()+120; passed=False
 while time.monotonic()<end:
  try: passed=json.loads(ready.read_text()).get('status')=='passed' and p.poll() is None
  except (FileNotFoundError,json.JSONDecodeError): pass
  if passed or p.poll() is not None: break
  time.sleep(.1)
 if not passed: raise RuntimeError('owner not ready')
 rows={}
 for name,cwd,platform in [('other-project',other,'android'),('other-platform',owner,'ios')]:
  out=R/name; out.mkdir(); call=subprocess.run(['python3','-I',mcp_client,request,str(out),cwd,'--',grantiva,'mcp','--project-dir',cwd,'--platform',platform],capture_output=True,text=True,timeout=45)
  (out/'client.out').write_text(call.stdout); (out/'client.err').write_text(call.stderr)
  raw=json.loads((out/'tree.json').read_text()); content=raw.get('result',{}).get('content',[]); text=' '.join(x.get('text','') for x in content)
  rows[name]={'clientRc':call.returncode,'isError':raw.get('result',{}).get('isError'),'text':text}
 (R/'negative-results.json').write_text(json.dumps(rows,indent=2)+'\n')
 stop=subprocess.run([grantiva,'runner','stop','--json'],cwd=owner,capture_output=True,text=True,timeout=30); (R/'stop.json').write_text(stop.stdout); (R/'stop.err').write_text(stop.stderr); t.join(timeout=30); so.close(); se.close()
 checks={'bothClients0':all(x['clientRc']==0 for x in rows.values()),'bothIsError':all(x['isError'] is True for x in rows.values()),'bothNoSession':all('No active runner session' in x['text'] for x in rows.values()),'bothExplainIgnored':all('ignored' in x['text'].lower() and ('another project' in x['text'].lower() or 'another platform' in x['text'].lower()) for x in rows.values()),'stop0':stop.returncode==0,'ownerEarned0':result.get('rc')==0}
 (R/'decoded.json').write_text(json.dumps({'checks':checks},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
finally:
 if p.poll() is None: subprocess.run([grantiva,'runner','stop','--json'],cwd=owner,capture_output=True,text=True)
 t.join(timeout=20); so.close(); se.close()
