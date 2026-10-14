#!/usr/bin/env python3
import json,subprocess,sys,time,select
out,cwd,platform,mode=sys.argv[1:5]
p=subprocess.Popen(['/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir',cwd,'--platform',platform],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
def send(x): p.stdin.write((x if isinstance(x,str) else json.dumps(x))+'\n');p.stdin.flush()
def read(timeout=.8):
 r,_,_=select.select([p.stdout],[],[],timeout);return p.stdout.readline().rstrip() if r else None
rows=[]
if mode=='resources':
 send({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'cov5','version':'1'}}});rows.append(read());send({'jsonrpc':'2.0','method':'notifications/initialized','params':{}})
 for i,u in enumerate(['grantiva://hierarchy','grantiva://screenshot','grantiva://unknown'],2):send({'jsonrpc':'2.0','id':i,'method':'resources/read','params':{'uri':u}});rows.append(read())
elif mode=='malformed':
 for x in ['not json',json.dumps({'id':7,'method':'tools/list'}),json.dumps({'method':'bad'}),json.dumps({'jsonrpc':'2.0','id':9,'result':{}}),'[]',json.dumps({'jsonrpc':'2.0','id':10,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'cov5','version':'1'}}})]:send(x);v=read();rows.append(v)
p.stdin.close();p.terminate();p.wait(timeout=5);open(out,'w').write(json.dumps(rows,indent=2)+'\n');open(out+'.stderr','w').write(p.stderr.read());print(json.dumps(rows))
