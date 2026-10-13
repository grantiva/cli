import json,os,sys,subprocess,time,hashlib,urllib.request
from pathlib import Path
from mcp_client import Client
r=Path(__file__).parent;s=json.loads((r/'state.json').read_text());os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=s['runnerHome'],GRANTIVA_SESSION_ID='fix4-5');checks=[];app=next(Path(s['scratch']).glob('StableDerivedData/Build/Products/*-iphonesimulator/Landmarks.app'))
def cmd(args,stem,cwd=None):
 p=subprocess.run(args,cwd=cwd,capture_output=True);(r/(stem+'.out')).write_bytes(p.stdout);(r/(stem+'.err')).write_bytes(p.stderr);assert p.returncode==0,(args,p.stderr);return p.stdout
cmd(['xcrun','simctl','terminate',s['udid'],'com.kylebrowning.Landmarks'],'stable2-terminate-before-install')
cmd(['xcrun','simctl','install',s['udid'],str(app)],'stable2-install')
def nodes(n):
 yield n
 for child in n.get('children',[]):yield from nodes(child)
def cycle(number):
 c=Client(s['binary'],s['project'],'ios',r/('ios-stable2-cycle'+str(number)))
 try:
  for attempt in range(30):
   q=c.tool('grantiva_a11y_tree',{})
   if not q['result'].get('isError'):break
   time.sleep(1)
  assert not q['result'].get('isError'),q
  time.sleep(1)
  def tap(label,identifier=False):
   before=c.tool('grantiva_a11y_tree',{});(r/('ios-stable2-cycle'+str(number))/('before-'+str(c.nextid)+'.json')).write_text(c.text(before))
   q=c.tool('grantiva_tap',{'label':label});t=c.text(q);assert not q['result'].get('isError'),q
   expected='Tapped on "'+label+'"'+(' (matched by identifier)' if identifier else '')+'. Updated hierarchy:';assert t.startswith(expected),t[:160]
   tree=json.loads(t.split('Updated hierarchy:\n',1)[1]);return tree
  tree=tap('Favorites');tree=tap('heart',True)
  assert any(n.get('label')=='Favorites' and n.get('type')=='XCUIElementTypeButton' and n.get('value')=='1' for n in nodes(tree))
  tree=tap('Landmarks');assert any(n.get('label')=='Landmarks' and n.get('type')=='XCUIElementTypeButton' and n.get('value')=='1' for n in nodes(tree))
  tree=tap('heart',True);assert any(n.get('label')=='Favorites' and n.get('type')=='XCUIElementTypeButton' and n.get('value')=='1' for n in nodes(tree))
  installed=Path(cmd(['xcrun','simctl','get_app_container',s['udid'],'com.kylebrowning.Landmarks','app'],'stable2-container-'+str(number)).decode().strip())
  entry={'cycle':number,'selectedAndUnselected':True,'tabNavigationConfirmed':True,'installedDylibSHA256':hashlib.sha256((installed/'Landmarks.debug.dylib').read_bytes()).hexdigest(),'buildDylibSHA256':hashlib.sha256((app/'Landmarks.debug.dylib').read_bytes()).hexdigest()};assert entry['installedDylibSHA256']==entry['buildDylibSHA256'];checks.append(entry);print(entry,flush=True)
 finally:c.close();(r/'ios-stable2-checks.json').write_text(json.dumps(checks,indent=2)+'\n')
for number in [1,2]:
 if number==2:cmd(['xcrun','simctl','terminate',s['udid'],'com.kylebrowning.Landmarks'],'stable2-terminate-'+str(number))
 cmd(['xcrun','simctl','launch',s['udid'],'com.kylebrowning.Landmarks'],'stable2-launch-'+str(number));cycle(number)
cmd([s['binary'],'runner','stop','--json'],'stable2-runner-stop',s['project'])
cmd([s['binary'],'runner','start','--platform','ios','--simulator',s['udid'],'--bundle-id','com.kylebrowning.Landmarks','--detach','--json'],'stable2-runner-start',s['project']);cycle(3)
