#!/usr/bin/env python3
import json,subprocess,sys,time
out=sys.argv[1];cwd=sys.argv[2];extra=sys.argv[3:]
call_session_tool='--call-session-tool' in extra
extra=[arg for arg in extra if arg != '--call-session-tool']
p=subprocess.Popen(['/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir',cwd,*extra],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
reqs=[{'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'cov5','version':'1'}}},{'jsonrpc':'2.0','method':'notifications/initialized','params':{}},{'jsonrpc':'2.0','id':2,'method':'tools/list','params':{}}]
for q in reqs:p.stdin.write(json.dumps(q)+'\n');p.stdin.flush()
responses=[]
while len([x for x in responses if 'id' in x])<2:
 line=p.stdout.readline()
 if not line:break
 responses.append(json.loads(line))
if call_session_tool:
 q={'jsonrpc':'2.0','id':3,'method':'tools/call','params':{'name':'grantiva_screenshot','arguments':{}}};p.stdin.write(json.dumps(q)+'\n');p.stdin.flush();responses.append(json.loads(p.stdout.readline()))
p.stdin.close();p.terminate();p.wait(timeout=5);err=p.stderr.read()
open(out,'w').write(json.dumps(responses,indent=2)+'\n');open(out+'.stderr','w').write(err)
print(json.dumps({'responses':len(responses),'ids':[x.get('id') for x in responses],'tools':len(next(x for x in responses if x.get('id')==2)['result']['tools'])}))
