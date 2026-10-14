#!/usr/bin/env python3
import json,subprocess,sys
out,cwd,platform,tool,args=sys.argv[1:6]
p=subprocess.Popen(['/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir',cwd,'--platform',platform],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
def ask(obj):
 p.stdin.write(json.dumps(obj)+'\n');p.stdin.flush();return json.loads(p.stdout.readline())
r=[ask({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'cov5','version':'1'}}})]
p.stdin.write(json.dumps({'jsonrpc':'2.0','method':'notifications/initialized','params':{}})+'\n');p.stdin.flush()
r.append(ask({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':tool,'arguments':json.loads(args)}}))
r.append(ask({'jsonrpc':'2.0','id':3,'method':'tools/list','params':{}}))
p.stdin.close();p.terminate();p.wait(timeout=5);open(out,'w').write(json.dumps(r,indent=2)+'\n');open(out+'.stderr','w').write(p.stderr.read());print(json.dumps({'call':r[1],'continuedToolCount':len(r[2]['result']['tools'])}))
