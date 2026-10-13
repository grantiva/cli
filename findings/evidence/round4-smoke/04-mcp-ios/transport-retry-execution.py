#!/usr/bin/env python3
import argparse, hashlib, http.server, json, os, pathlib, subprocess, threading, time, urllib.error, urllib.request
from mcp_client import Client
from candidate_identity import validate as validate_identity

def digest(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def good(reply): return not reply.get('error') and not reply.get('result',{}).get('isError')
def walk(node):
    yield node
    for child in node.get('children',[]): yield from walk(child)

ap=argparse.ArgumentParser(); ap.add_argument('--candidate-manifest',required=True); ap.add_argument('--ownership-manifest',required=True); ap.add_argument('--source-root',required=True); ap.add_argument('--binary',required=True); ap.add_argument('--bundle',required=True); ap.add_argument('--runner',required=True); ap.add_argument('--runner-home',required=True); ap.add_argument('--platform',choices=('ios','android'),required=True)
ap.add_argument('--device',required=True); ap.add_argument('--android-avd'); ap.add_argument('--project',required=True); ap.add_argument('--no-session-project',required=True); ap.add_argument('--large-seed',required=True); ap.add_argument('--ios-simctl'); ap.add_argument('--ios-app-id'); ap.add_argument('--evidence',required=True); ap.add_argument('--pairs',type=int,default=10)
a=ap.parse_args(); root=pathlib.Path(a.evidence).resolve(); root.mkdir(parents=True,exist_ok=False)
for p in (a.binary,a.runner_home,a.project,a.no_session_project):
    if not pathlib.Path(p).exists(): raise SystemExit(f'missing {p}')
if a.pairs!=10: raise SystemExit('binding smoke requires exactly 10 pairs')
if not pathlib.Path(a.large_seed).is_file(): raise SystemExit('large hierarchy seed missing')
if a.platform=='ios' and (not a.ios_simctl or not a.ios_app_id): raise SystemExit('iOS retry requires simctl and app id')
if os.environ.get('GRANTIVA_API_KEY'): raise SystemExit('GRANTIVA_API_KEY must be unset')
if (pathlib.Path(a.no_session_project)/'.grantiva/session.json').exists(): raise SystemExit('no-session project contains a session')
session=json.loads((pathlib.Path(a.project)/'.grantiva/session.json').read_text())
if session.get('platform')!=a.platform or a.device not in (session.get('udid'),session.get('device'),session.get('deviceId')): raise SystemExit('active session does not match explicit platform/device')
os.environ.update(GRANTIVA_RUNNER_HOME=str(pathlib.Path(a.runner_home).resolve()),MAESTRO_RUNNER_HOME=str(pathlib.Path(a.runner_home).resolve()),GRANTIVA_SESSION_ID='fix4-8')
identity=validate_identity(a.candidate_manifest,a.ownership_manifest,source_root=a.source_root,binary=a.binary,bundle=a.bundle,runner=a.runner,runner_home=a.runner_home,platform=a.platform,device=a.device,android_avd=a.android_avd)
(root/'provenance.json').write_text(json.dumps({**identity,'binary':str(pathlib.Path(a.binary).resolve()),'runnerHome':str(pathlib.Path(a.runner_home).resolve()),'platform':a.platform,'device':a.device,'project':str(pathlib.Path(a.project).resolve()),'apiKey':'unset'},indent=2)+'\n')
checks=[]
no=Client(a.binary,a.no_session_project,a.platform,root/'no-session')
try:
    reply=no.tool('grantiva_script',{}); text=no.text(reply)
    assert reply['result']['isError'] and "No active runner session" in text,(reply,text)
    checks.append({'L65NoSessionPrecedence':True,'text':text})
finally:no.close()
c=Client(a.binary,a.project,a.platform,root/'active')
try:
    for attempt in range(30):
        ready=c.tool('grantiva_a11y_tree',{})
        if good(ready): break
        time.sleep(1)
    assert good(ready),ready
    for arguments,expected in [({},"Error: Invalid argument: 'steps' is required."),({'steps':'tap'},"Error: Invalid argument: 'steps' array is required.")]:
        reply=c.tool('grantiva_script',arguments); assert reply['result']['isError'] and c.text(reply)==expected,reply
    empty=c.tool('grantiva_script',{'steps':[]}); assert good(empty) and 'Final hierarchy:' in c.text(empty)
    checks.append({'L65ActiveExact':True,'wrongTypeRetained':True,'emptyRetained':True})
    seed=json.loads(pathlib.Path(a.large_seed).read_text()); assert isinstance(seed,list) and seed
    for item in seed:
        reply=c.tool(item['name'],item.get('arguments',{})); assert good(reply),(item,reply)
    pre_resource=c.call('resources/read',{'uri':'grantiva://hierarchy'}); pre_tool=c.tool('grantiva_a11y_tree',{}); pre_sizes=[len((json.dumps(x,separators=(',',':'))+'\n').encode()) for x in (pre_resource,pre_tool)]; assert all(x>65536 for x in pre_sizes),pre_sizes
    checks.append({'deterministicLargeHierarchySeed':str(pathlib.Path(a.large_seed).resolve()),'preflightResponseBytes':pre_sizes})
    c.call('resources/subscribe',{'uri':'grantiva://hierarchy'}); large=[]; small=[]; triggers=[]
    for pair in range(10):
        ids=[c.send('resources/read',{'uri':'grantiva://hierarchy'}),c.send('tools/call',{'name':'grantiva_a11y_tree','arguments':{}})]; sid=c.send('tools/list',{}); tid=c.send('tools/call',{'name':'grantiva_script','arguments':{'steps':[{'wait':0.01}]}})
        for request_id in ids+[sid,tid]: assert good(c.wait(request_id)),request_id
        large.extend(ids); small.append(sid); triggers.append(tid)
    deadline=time.monotonic()+5
    while time.monotonic()<deadline and sum(m.get('method')=='notifications/resources/updated' for m,n in c.messages)<10: time.sleep(.1)
    for request_id in large:
        rows=[n for m,n in c.messages if m.get('id')==request_id]; assert len(rows)==1 and rows[0]>65536,(request_id,rows)
    for request_id in small:
        rows=[n for m,n in c.messages if m.get('id')==request_id]; assert len(rows)==1 and rows[0]<65536,(request_id,rows)
    notes=[m for m,n in c.messages if m.get('method')=='notifications/resources/updated']; assert len(notes)==10,len(notes)
    ids=[m['id'] for m,n in c.messages if 'id' in m]; assert len(ids)==len(set(ids))
    checks.append({'transportPairs':10,'largeResponses':len(large),'smallResponses':len(small),'notifications':len(notes),'uniqueIDs':True})
finally:c.close()
if a.platform=='ios':
    session_path=pathlib.Path(a.project)/'.grantiva/session.json'; original=session_path.read_bytes(); session_doc=json.loads(original); upstream=session_doc['wdaPort']; records=[]
    class Proxy(http.server.BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def do_GET(self): self.forward()
        def do_POST(self): self.forward()
        def forward(self):
            body=self.rfile.read(int(self.headers.get('Content-Length',0))); req=urllib.request.Request(f'http://127.0.0.1:{upstream}'+self.path,data=body or None,method=self.command,headers={'Content-Type':'application/json'}); started=time.monotonic()
            try:
                with urllib.request.urlopen(req,timeout=20) as result: status=result.status; response=result.read()
            except urllib.error.HTTPError as error: status=error.code; response=error.read()
            records.append({'method':self.command,'path':self.path,'status':status,'monotonic':started}); self.send_response(status); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(response))); self.end_headers(); self.wfile.write(response)
    proxy=http.server.ThreadingHTTPServer(('127.0.0.1',0),Proxy); thread=threading.Thread(target=proxy.serve_forever,daemon=True); thread.start(); retry=None
    try:
        session_doc['wdaPort']=proxy.server_port; session_doc['port']=proxy.server_port; session_path.write_text(json.dumps(session_doc)); retry=Client(a.binary,a.project,'ios',root/'retry'); subprocess.run([a.ios_simctl,'simctl','terminate',a.device,a.ios_app_id],check=True,capture_output=True,timeout=20); start=len(records); response=retry.tool('grantiva_tap',{'label':'Favorites'}); text=retry.text(response); assert response['result'].get('isError') and f'{a.ios_app_id} is not running' in text
        finds=[x for x in records[start:] if x['path'].endswith('/elements')]; assert len(finds)==2 and all(x['status']==400 for x in finds) and finds[1]['monotonic']-finds[0]['monotonic']>=1,finds; checks.append({'L66RetryError':text,'lookups':2,'minimumRetryDelaySeconds':1})
    finally:
        session_path.write_bytes(original)
        if retry: retry.close()
        proxy.shutdown(); proxy.server_close(); thread.join(); (root/'retry-http.json').write_text(json.dumps(records,indent=2)+'\n')
(root/'acceptance.json').write_text(json.dumps({'passed':True,'platform':a.platform,'checks':checks},indent=2)+'\n')
