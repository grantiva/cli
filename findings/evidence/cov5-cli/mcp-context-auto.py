import json,subprocess,sys
out,cwd=sys.argv[1:3]
p=subprocess.Popen(['/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir',cwd],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
def ask(x):p.stdin.write(json.dumps(x)+'\n');p.stdin.flush();return json.loads(p.stdout.readline())
r=[ask({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'cov5','version':'1'}}})];p.stdin.write(json.dumps({'jsonrpc':'2.0','method':'notifications/initialized','params':{}})+'\n');p.stdin.flush();r.append(ask({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':'grantiva_context','arguments':{}}}));p.terminate();p.wait();open(out,'w').write(json.dumps(r,indent=2));print(json.dumps(r[-1]))
