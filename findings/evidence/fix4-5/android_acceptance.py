import json,os,sys,time
from pathlib import Path
from mcp_client import Client
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());a=s['android'];os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-5')
c=Client(s['binary'],a['project'],'android',r/'android-final');checks=[]
try:
 for attempt in range(30):
  q=c.tool('grantiva_a11y_tree',{})
  if not q.get('result',{}).get('isError'):break
  time.sleep(1)
 assert not q['result'].get('isError'),q
 for args,expected in [({},"Error: Invalid argument: 'steps' is required."),({'steps':'tap'},"Error: Invalid argument: 'steps' array is required.")]:
  q=c.tool('grantiva_script',args);assert q['result']['isError'] and c.text(q)==expected,q;checks.append(expected)
 q=c.tool('grantiva_script',{'steps':[]});assert not q['result'].get('isError') and 'Final hierarchy:' in c.text(q);checks.append('empty steps hierarchy')
 c.call('resources/subscribe',{'uri':'grantiva://hierarchy'})
 large=[];small=[];scripts=[]
 for pair in range(10):
  ids=[c.send('resources/read',{'uri':'grantiva://hierarchy'}),c.send('tools/call',{'name':'grantiva_a11y_tree','arguments':{}})]
  smallid=c.send('tools/list',{});scriptid=c.send('tools/call',{'name':'grantiva_script','arguments':{'steps':[{'wait':0.01}]}})
  for id in ids+[smallid,scriptid]:
   q=c.wait(id,90);assert not q.get('error') and not q.get('result',{}).get('isError'),q
  large+=ids;small.append(smallid);scripts.append(scriptid)
  print('pair',pair+1,'received',ids,flush=True)
 end=time.monotonic()+5
 while time.monotonic()<end and sum(m.get('method')=='notifications/resources/updated' for m,n in c.messages)<10:time.sleep(.1)
 for id in large:
  entries=[(m,n) for m,n in c.messages if m.get('id')==id];assert len(entries)==1 and entries[0][1]>65536,(id,[(m.get('id'),n) for m,n in entries])
 for id in small:
  entries=[(m,n) for m,n in c.messages if m.get('id')==id];assert len(entries)==1 and entries[0][1]<65536,(id,entries)
 notes=[m for m,n in c.messages if m.get('method')=='notifications/resources/updated'];assert len(notes)==10,len(notes)
 ids=[m['id'] for m,n in c.messages if 'id' in m];assert len(ids)==len(set(ids)),ids
 checks.append({'tenConcurrentPairs':large,'sizes':[n for m,n in c.messages if m.get('id') in large],'smallIDs':small,'notifications':len(notes),'allIDsUnique':True})
finally:
 (r/'android-final-checks.json').write_text(json.dumps(checks,indent=2)+'\n');c.close()
