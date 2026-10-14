#!/usr/bin/env python3
import json,subprocess,sys
out,cwd=sys.argv[1:3]
p=subprocess.Popen(['/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir',cwd,'--platform','ios'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
for x in [{'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'candidate5-cli','version':'1'}}},{'jsonrpc':'2.0','method':'notifications/initialized','params':{}},{'jsonrpc':'2.0','id':2,'method':'tools/list','params':{}}]: p.stdin.write(json.dumps(x)+'\n')
p.stdin.flush(); rows=[]
while len(rows)<2:
 x=json.loads(p.stdout.readline());
 if 'id' in x: rows.append(x)
p.stdin.close();p.terminate();p.wait(timeout=5); open(out,'w').write(json.dumps(rows,indent=2)+'\n');open(out+'.stderr','w').write(p.stderr.read())
tools=next(x for x in rows if x.get('id')==2)['result']['tools']; sims={x['name']:x['inputSchema']['properties']['simulator']['description'] for x in tools if 'simulator' in x['inputSchema'].get('properties',{})}; print(json.dumps(sims,indent=2))
