import json,os,sys,time
from pathlib import Path
from mcp_client import Client
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-5')
c=Client(s['binary'],s['project'],'ios',r/'ios-stable-transport');checks=[]
def tool(name,args):
 q=c.tool(name,args);assert not q.get('error') and not q['result'].get('isError'),q
 return c.text(q)
def walk(n):
 yield n
 for child in n.get('children',[]):yield from walk(child)
try:
 tool('grantiva_tap',{'label':'Mountains'})
 before=json.loads(tool('grantiva_a11y_tree',{}));(r/'ios-stable-before-app-exclusion.json').write_text(json.dumps(before,indent=2))
 assert before['type']=='XCUIElementTypeApplication' and before['label']=='Landmarks'
 assert any(n.get('label')=='Landmarks' and n.get('type')=='XCUIElementTypeButton' for n in walk(before))
 t=tool('grantiva_tap',{'label':'Landmarks'});assert 'Golden Gate Bridge' in t;checks.append('Landmarks back button wins despite application label')
 tree=json.loads(tool('grantiva_a11y_tree',{}));node=next(n for n in walk(tree) if n.get('label')=='Favorites' and n.get('type')=='XCUIElementTypeButton')
 frame=node['frame'];xy={'x':frame['x']+frame['width']/2,'y':frame['y']+frame['height']/2};(r/'ios-stable-coordinate-input.json').write_text(json.dumps({'frame':frame,'arguments':xy},indent=2))
 t=tool('grantiva_tap',xy);assert t.startswith('Tapped at (') and 'Favorites' in t;checks.append('coordinates from live Favorites frame in points')
 tool('grantiva_tap',{'label':'Landmarks'})
 c.call('resources/subscribe',{'uri':'grantiva://hierarchy'})
 large=[];small=[];scripts=[]
 for pair in range(10):
  ids=[c.send('resources/read',{'uri':'grantiva://hierarchy'}),c.send('tools/call',{'name':'grantiva_a11y_tree','arguments':{}})]
  smallid=c.send('tools/list',{})
  scriptid=c.send('tools/call',{'name':'grantiva_script','arguments':{'steps':[{'wait':0.01}]}})
  for id in ids+[smallid,scriptid]:
   reply=c.wait(id,90);assert not reply.get('error') and not reply.get('result',{}).get('isError'),reply
  large.extend(ids);small.append(smallid);scripts.append(scriptid)
  print('pair',pair+1,'received',ids,'small',smallid,'notification trigger',scriptid,flush=True)
 end=time.monotonic()+5
 while time.monotonic()<end and sum(m.get('method')=='notifications/resources/updated' for m,n in c.messages)<10:time.sleep(.1)
 for id in large:
  entries=[(m,n) for m,n in c.messages if m.get('id')==id];assert len(entries)==1,(id,entries)
  assert entries[0][1]>65536,(id,entries[0][1])
 for id in small:
  entries=[(m,n) for m,n in c.messages if m.get('id')==id];assert len(entries)==1 and entries[0][1]<65536,(id,entries)
 notes=[m for m,n in c.messages if m.get('method')=='notifications/resources/updated'];assert len(notes)==10,len(notes)
 ids=[m['id'] for m,n in c.messages if 'id' in m];assert len(ids)==len(set(ids)),ids
 assert not c.invalid,c.invalid
 checks.append({'tenConcurrentPairs':large,'sizes':[n for m,n in c.messages if m.get('id') in large],'smallIDs':small,'notifications':len(notes),'allIDsUnique':True})
finally:
 (r/'ios-stable-transport-checks.json').write_text(json.dumps(checks,indent=2)+'\n');c.close()
