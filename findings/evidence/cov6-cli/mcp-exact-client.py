#!/usr/bin/env python3
import json,subprocess,sys,select
out,cwd=sys.argv[1:3]
p=subprocess.Popen(['/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir',cwd,'--platform','ios'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
def send(x): p.stdin.write((x if isinstance(x,str) else json.dumps(x,separators=(',',':')))+'\n');p.stdin.flush()
def read(t=.8):
 r,_,_=select.select([p.stdout],[],[],t); return p.stdout.readline().rstrip() if r else None
rows=[]
for x in ['not json',{'id':7,'method':'tools/list'},{'method':'bad'},{'jsonrpc':'2.0','id':9,'result':{}},[]]: send(x); rows.append(read())
for x in [
 {'jsonrpc':'2.0','id':10,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'candidate5-cli','version':'1'}}},
 {'jsonrpc':'2.0','method':'notifications/initialized','params':{}},
 {'jsonrpc':'2.0','id':11,'method':'tools/list','params':{}},
 {'jsonrpc':'2.0','id':12,'method':'tools/call','params':{'name':'grantiva_screenshot','arguments':{}}}
]:
 send(x)
 if 'id' in x: rows.append(read(2))
p.stdin.close();p.terminate();p.wait(timeout=5)
open(out,'w').write(json.dumps(rows,indent=2)+'\n');open(out+'.stderr','w').write(p.stderr.read())
print(json.dumps({'lines':rows}))
