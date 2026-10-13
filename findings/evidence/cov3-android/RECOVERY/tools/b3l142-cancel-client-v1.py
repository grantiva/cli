#!/usr/bin/env python3
import json, os, pathlib, queue, subprocess, sys, threading, time

root=pathlib.Path(sys.argv[1]); project=pathlib.Path(sys.argv[2]); grantiva=sys.argv[3]
env=os.environ.copy()
p=subprocess.Popen([grantiva,'mcp','--project-dir',str(project),'--platform','android'],cwd=project,env=env,
 stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1,start_new_session=True)
(root/'mcp.pid').write_text(str(p.pid)+'\n')
q=queue.Queue(); responses=[]
def stdout_reader():
 for line in p.stdout:
  (root/'stdout.raw').open('a').write(line); q.put(line)
def stderr_reader():
 with (root/'stderr.raw').open('a') as f:
  for line in p.stderr: f.write(line); f.flush()
threading.Thread(target=stdout_reader,daemon=True).start(); threading.Thread(target=stderr_reader,daemon=True).start()
def send(obj):
 raw=json.dumps({'jsonrpc':'2.0',**obj},separators=(',',':'))
 with (root/'stdin.raw').open('a') as f:f.write(raw+'\n')
 p.stdin.write(raw+'\n');p.stdin.flush()
def await_id(want,timeout=10):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  try: line=q.get(timeout=.2)
  except queue.Empty: continue
  try: doc=json.loads(line)
  except Exception: continue
  responses.append(doc)
  if doc.get('id')==want:return doc
 raise RuntimeError(f'timed out waiting for {want}')
def snapshot(path):
 data=subprocess.check_output(['ps','-axo','pid=,ppid=,state=,etime=,command='],text=True)
 path.write_text(data)
 rows=[]
 for line in data.splitlines():
  parts=line.strip().split(None,4)
  if len(parts)>=5 and parts[0].isdigit() and parts[1].isdigit(): rows.append((int(parts[0]),int(parts[1]),line))
 keep={p.pid}; changed=True
 while changed:
  changed=False
  for pid,ppid,line in rows:
   if ppid in keep and pid not in keep: keep.add(pid);changed=True
 descendants=[line for pid,ppid,line in rows if pid in keep and pid!=p.pid]
 project_build=[line for pid,ppid,line in rows if str(project) in line and ('gradle' in line.lower() or 'java' in line.lower())]
 path.with_suffix(path.suffix+'.descendants').write_text('\n'.join(descendants)+'\n')
 path.with_suffix(path.suffix+'.project-build').write_text('\n'.join(project_build)+'\n')
 return [line for line in descendants if 'gradle' in line.lower() or 'java' in line.lower()]
try:
 send({'id':'init','method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'b3l142-cancel','version':'1'}}})
 (root/'initialize.json').write_text(json.dumps(await_id('init'),indent=2)+'\n')
 send({'method':'notifications/initialized','params':{}})
 send({'id':'build-cancel','method':'tools/call','params':{'name':'grantiva_build','arguments':{}}})
 time.sleep(2.0)
 active=snapshot(root/'processes-before-cancel.txt')
 (root/'project-build-processes-before.json').write_text(json.dumps(active,indent=2)+'\n')
 if not active: raise RuntimeError('no real Gradle/Java process names the scratch project at cancel time')
 active_pids={int(x.strip().split(None,1)[0]) for x in active}
 (root/'tracked-build-pids.json').write_text(json.dumps(sorted(active_pids),indent=2)+'\n')
 cancel_at=time.time(); (root/'cancel-epoch.txt').write_text(f'{cancel_at:.6f}\n')
 send({'method':'notifications/cancelled','params':{'requestId':'build-cancel','reason':'B3-L14.2 exact runtime cancellation'}})
 send({'id':'post-cancel-list','method':'tools/list','params':{}})
 snapshot(root/'processes-at-cancel.txt')
 deadline=time.monotonic()+5; gone=False
 while time.monotonic()<deadline:
  snapshot(root/'processes-poll-latest.txt')
  ps=subprocess.check_output(['ps','-axo','pid=,ppid=,state=,etime=,command='],text=True)
  remain=[x for x in ps.splitlines() if x.strip().split(None,1) and x.strip().split(None,1)[0].isdigit() and int(x.strip().split(None,1)[0]) in active_pids]
  (root/'tracked-build-survivors-latest.txt').write_text('\n'.join(remain)+'\n')
  if not remain: gone=True;break
  time.sleep(.1)
 snapshot(root/'processes-after-5s.txt')
 (root/'child-gone-within-5s.txt').write_text(('true' if gone else 'false')+'\n')
 listed=await_id('post-cancel-list',8)
 (root/'tools-list.json').write_text(json.dumps(listed,indent=2)+'\n')
 # Give a wrongly emitted cancelled response time to arrive.
 end=time.monotonic()+1.5
 while time.monotonic()<end:
  try: line=q.get(timeout=.1)
  except queue.Empty: continue
  try: responses.append(json.loads(line))
  except Exception: pass
 (root/'responses.json').write_text(json.dumps(responses,indent=2)+'\n')
 ids=[x.get('id') for x in responses if isinstance(x,dict)]
 checks={'realBuildActiveAtCancel':bool(active),'childGoneWithin5s':gone,
         'noCancelledIDResponse':'build-cancel' not in ids,
         'nextToolsListAnswered':'post-cancel-list' in ids and bool(listed.get('result',{}).get('tools'))}
 (root/'decoded.json').write_text(json.dumps({'checks':checks,'responseIDs':ids},indent=2)+'\n')
 if not all(checks.values()): raise RuntimeError(checks)
finally:
 try:p.stdin.close()
 except Exception:pass
 try:p.terminate();p.wait(timeout=5)
 except Exception:
  try:p.kill();p.wait(timeout=2)
  except Exception:pass
 (root/'mcp.exit').write_text(str(p.returncode)+'\n')
