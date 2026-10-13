import os,json,time
from pathlib import Path
from mcp_client import Client
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-5');checks=[]
c=Client(s['binary'],s['project'],'ios',r/'ios-final-stable-selector')
try:
 for args,expected in [({},"Error: Invalid argument: 'steps' is required."),({'steps':'tap'},"Error: Invalid argument: 'steps' array is required.")]:
  q=c.tool('grantiva_script',args);assert q['result']['isError'] and c.text(q)==expected,q;checks.append({'script':args,'text':c.text(q),'passed':True})
 q=c.tool('grantiva_script',{'steps':[]});assert not q['result'].get('isError');checks.append({'emptySteps':True})
 requests=[json.loads(x) for x in (r/'ios-stable-selector/requests.jsonl').read_text().splitlines()]
 for req in requests:
  if req['method']!='tools/call':continue
  p=req['params'];name=p['name'];args=p['arguments'];q=c.tool(name,args);t=c.text(q);assert not q['result'].get('isError'),q
  if name=='grantiva_tap':
   label=args['label'];annotation=' (matched by identifier)' if label=='heart' else ' (matched by placeholder)' if label=='Name' else ''
   expected='Tapped on "'+label+'"'+annotation+'. Updated hierarchy:';assert t.startswith(expected),t[:200];checks.append({'label':label,'prefix':expected,'passed':True})
  elif name=='grantiva_a11y_tree':(r/'ios-final-stable-selector'/('before-'+str(c.nextid)+'.json')).write_text(t)
  else:checks.append({'script':args,'passed':True})
finally:
 c.close();(r/'ios-final-stable-selector-checks.json').write_text(json.dumps(checks,indent=2))
print(json.dumps(checks))
