#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,os,plistlib,signal,subprocess,sys,time,urllib.request

SDD=Path(__file__).resolve().parent
sys.path.insert(0,str(SDD/'task-8-harness'))
from mcp_client import Client

APP_ID='com.kylebrowning.Landmarks'
PROTECTED_IDS={'B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C','FE441EE5-BBFC-4981-B68A-59C0DBCE26D6'}
PROTECTED_NAMES={'iPhone 17 Pro','iPhone 18 Pro'}
REPO=SDD.parents[2];INPUTS=REPO/'findings/evidence/fix4-5-tab/regression-inputs';GLOBAL=Path('/tmp/grantiva-sessions')
EXPECTED_FLOWS=['01-browse','02-favorite','03-edit','12-quote-label']
RESTORE_LABEL='Restore Navigation State, Restores previously saved state'

ap=argparse.ArgumentParser()
ap.add_argument('--ownership',required=True)
ap.add_argument('--app',required=True)
ap.add_argument('--commit',required=True)
ap.add_argument('--output',required=True)
ap.add_argument('--binary',required=True)
ap.add_argument('--build-evidence',required=True)
a=ap.parse_args()

ownership_path=Path(a.ownership).resolve();app=Path(a.app).resolve();binary=Path(a.binary).resolve();out=Path(a.output).resolve();build_evidence=Path(a.build_evidence).resolve()
assert ownership_path.is_file() and app.is_dir() and binary.is_file() and build_evidence.is_dir() and not out.exists()
assert build_evidence.name=='public-container-safearea-build',build_evidence
out.mkdir(parents=True)
ownership=json.loads(ownership_path.read_text());commit=a.commit
assert len(commit)==40 and all(c in '0123456789abcdef' for c in commit)
assert len(commit)==40
for key in ('udid','name','runtime','scratch','home','project','sessionId','app','demoCommit','cliSource','cliSHA256','runnerSource','runnerVersion','owned'):
 assert key in ownership,key
udid=ownership['udid'];runtime=ownership['runtime'];scratch=Path(ownership['scratch']).resolve();home=Path(ownership['home']).resolve();project=Path(ownership['project']).resolve();session_id=ownership['sessionId']
assert ownership['owned'] is True and udid not in PROTECTED_IDS and ownership['name'] not in PROTECTED_NAMES
assert runtime in ('iOS 26.0','iOS 27.0') and Path(ownership['app']).resolve()==app and ownership['demoCommit']==commit
assert home.is_relative_to(scratch) and project.is_relative_to(scratch) and home.is_dir() and project.is_dir()
assert hashlib.sha256(binary.read_bytes()).hexdigest()==ownership['cliSHA256']
assert os.environ.get('GRANTIVA_API_KEY') in (None,'')

env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.update(GRANTIVA_RUNNER_HOME=str(home),MAESTRO_RUNNER_HOME=str(home),GRANTIVA_SESSION_ID=session_id)
os.environ.pop('GRANTIVA_API_KEY',None);os.environ.update(GRANTIVA_RUNNER_HOME=str(home),MAESTRO_RUNNER_HOME=str(home),GRANTIVA_SESSION_ID=session_id)
checks=[];commands=[];session=project/'.grantiva/session.json';simctl=['xcrun','simctl'];active_client=None;installed=None;tracked_runner=set();tracked_app=set()

def save(name,value):
 (out/(name+'.json')).write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')

def command(name,argv,expected=0,cwd=None):
 argv=list(map(str,argv));started=time.time();p=subprocess.run(argv,cwd=cwd or project,env=env,capture_output=True,timeout=240)
 (out/(name+'.stdout')).write_bytes(p.stdout);(out/(name+'.stderr')).write_bytes(p.stderr)
 record={'argv':argv,'cwd':str(Path(cwd or project).resolve()),'environment':{'GRANTIVA_RUNNER_HOME':str(home),'MAESTRO_RUNNER_HOME':str(home),'GRANTIVA_SESSION_ID':session_id,'GRANTIVA_API_KEY':'unset'},'start':started,'end':time.time(),'exit':p.returncode}
 save(name,record);commands.append(record)
 assert expected is None or p.returncode==expected,(name,p.returncode,p.stderr.decode(errors='replace'))
 return p

def tree_manifest(root):
 rows=[]
 for path in sorted(root.rglob('*')):
  rel=str(path.relative_to(root))
  if path.is_symlink():rows.append({'path':rel,'type':'symlink','target':os.readlink(path)})
  elif path.is_file():rows.append({'path':rel,'type':'file','size':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 return rows

def file_manifest(root):
 return [{'path':str(p.relative_to(root)),'size':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(root.rglob('*')) if p.is_file() and not p.is_symlink()]

def nodes(node):
 yield node
 for child in node.get('children',[]):yield from nodes(child)

def good(reply):return not reply.get('error') and not reply.get('result',{}).get('isError')

def parse_tree(reply):
 assert good(reply),reply
 return json.loads(Client.text(reply))

def favorites_button(tree,selected):
 buttons=[n for n in nodes(tree) if n.get('type')=='XCUIElementTypeButton' and n.get('label')=='Favorites']
 assert len(buttons)==1,buttons
 button=buttons[0];assert button.get('identifier')=='heart',button
 is_selected=str(button.get('value',''))=='1';assert is_selected is selected,(selected,button)
 impostors=[n for n in nodes(tree) if n.get('identifier')=='heart' and n is not button]
 assert not impostors,impostors
 return {'type':button.get('type'),'label':button.get('label'),'identifier':button.get('identifier'),'value':button.get('value'),'frame':button.get('frame')}

def selected_button(tree,label):
 rows=[n for n in nodes(tree) if n.get('type')=='XCUIElementTypeButton' and n.get('label')==label and str(n.get('value',''))=='1']
 assert len(rows)==1,(label,rows)

def tab_contract(tree):
 tabs=[n for n in nodes(tree) if n.get('type')=='XCUIElementTypeButton' and n.get('label') in ('Landmarks','Favorites','Deep Links')]
 tabs=sorted(tabs,key=lambda n:n.get('frame',{}).get('x',-1));assert [n.get('label') for n in tabs]==['Landmarks','Favorites','Deep Links'],tabs
 assert all(n.get('frame',{}).get('width',0)>0 and n.get('frame',{}).get('height',0)>0 for n in tabs),tabs
 expected={'Landmarks':'map','Favorites':'heart','Deep Links':'link'};images={}
 for button in tabs:
  scoped=[n.get('identifier') for n in nodes(button) if n.get('type')=='XCUIElementTypeImage' and n.get('identifier')]
  semantic=expected[button['label']];assert any(x==semantic or x.startswith(semantic+'.') for x in scoped),(button['label'],scoped);images[button['label']]=scoped
 return {'labels':[n.get('label') for n in tabs],'frames':[n.get('frame') for n in tabs],'buttonScopedImageIdentifiers':images}

def wait_tree(client,name):
 for _ in range(60):
  reply=client.tool('grantiva_a11y_tree',{})
  if good(reply):
   tree=parse_tree(reply);save(name,tree);return tree
  time.sleep(.5)
 raise AssertionError((name,reply))

def tap(client,label,annotation=None):
 reply=client.tool('grantiva_tap',{'label':label});text=Client.text(reply);assert good(reply),(label,reply)
 expected=f'Tapped on "{label}"'+(f' (matched by {annotation})' if annotation else '')+'. Updated hierarchy:'
 assert text.startswith(expected),(expected,text[:240])
 return json.loads(text.split('Updated hierarchy:\n',1)[1])

def tap_with_scroll(client,name,label):
 for attempt in range(5):
  tree=wait_tree(client,f'{name}-discovery-{attempt}')
  if any(n.get('label')==label for n in nodes(tree)):return tap(client,label)
  reply=client.tool('grantiva_swipe',{'direction':'up'});assert good(reply),(name,attempt,reply);save(f'{name}-swipe-{attempt}',reply)
 raise AssertionError((name,label,'not discovered after bounded upward scrolls'))

def host_process(pid):return command(name='pid-'+str(pid),argv=['/bin/ps','-p',str(pid),'-o','command='],expected=None).stdout.decode().strip()
def global_sessions(pid):return sorted(str(p) for p in GLOBAL.glob(str(pid)+'*')) if GLOBAL.exists() else []

def stop_runner(name,doc):
 pid=int(doc['pid'])
 p=command(name,[binary,'runner','stop','--json'],expected=0)
 for _ in range(40):
  if not host_process(pid):break
  time.sleep(.25)
 assert not host_process(pid) and not session.exists() and not global_sessions(pid),(name,pid,global_sessions(pid))
 save(name+'-absence',{'runnerPID':pid,'projectSessionAbsent':True,'globalSessionsAbsent':True,'processAbsent':True})
 return p

def start_runner(name):
 command(name,[binary,'runner','start','--platform','ios','--simulator',udid,'--bundle-id',APP_ID,'--detach','--json'])
 for _ in range(80):
  if session.exists():
   doc=json.loads(session.read_text())
   if doc.get('state')=='ready':
    assert doc.get('udid')==udid and isinstance(doc.get('port'),int),doc
    pid=int(doc['pid']);proc=host_process(pid);assert str(home) in proc and udid in proc,(pid,proc);tracked_runner.add(pid);save(name+'-session',doc);return doc
  time.sleep(.25)
 raise AssertionError((name,'no ready session'))

def new_client(name):return Client(binary,project,'ios',out/name)

def app_processes(name):
 p=command(name,simctl+['spawn',udid,'/bin/ps','-axo','pid=,command=']);rows=[]
 for line in p.stdout.decode(errors='replace').splitlines():
  parts=line.strip().split(None,1)
  if len(parts)==2 and installed and (parts[1]==str(installed/'Landmarks') or parts[1].startswith(str(installed)+' ')):rows.append({'pid':int(parts[0]),'command':parts[1]})
 save(name+'-matches',rows);return rows

def app_pid(name):
 rows=app_processes(name);assert len(rows)==1,rows;tracked_app.add(rows[0]['pid']);return rows[0]['pid']

def background_save(name,session_doc,expected):
 port=session_doc['port'];url=f'http://127.0.0.1:{port}/wda/homescreen';started=time.time();req=urllib.request.Request(url,data=b'{}',method='POST',headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=20) as response:body=response.read();status=response.status
 (out/(name+'.response')).write_bytes(body);save(name,{'method':'POST','url':url,'body':{},'start':started,'end':time.time(),'status':status});assert 200<=status<300
 data=Path(command(name+'-data-container',simctl+['get_app_container',udid,APP_ID,'data']).stdout.decode().strip());pref=data/'Library/Preferences'/f'{APP_ID}.plist';reads=[];diagnostic_start=time.monotonic()
 for index,delay in enumerate((0,.25,.5,1.0)):
  time.sleep(delay);row={'index':index,'delayFromPrior':delay,'elapsedSinceDiagnosticStart':time.monotonic()-diagnostic_start}
  defaults=command(f'{name}-defaults-{index}',simctl+['spawn',udid,'defaults','read',APP_ID,'NavigatorState'],expected=None);row.update(defaultsExit=defaults.returncode,defaultsSHA256=hashlib.sha256(defaults.stdout).hexdigest(),defaultsBytes=len(defaults.stdout))
  if pref.is_file():
   raw=pref.read_bytes();(out/f'{name}-preferences-{index}.plist').write_bytes(raw);row.update(preferencePath=str(pref),preferenceSHA256=hashlib.sha256(raw).hexdigest(),preferenceBytes=len(raw))
   try:
    encoded=plistlib.loads(raw).get('NavigatorState')
    if isinstance(encoded,bytes):row['decodedNavigatorState']=json.loads(encoded);row['navigatorStateSHA256']=hashlib.sha256(encoded).hexdigest()
   except Exception as error:row['decodeDiagnostic']=repr(error)
  reads.append(row)
 evidence={'expectedSelection':expected,'acceptanceRole':'secondary flush-timing diagnostic only','reads':reads};save(name+'-timed-preference-diagnostics',evidence);return evidence

def background_resume(name,client,session_doc,expected):
 before=app_pid(name+'-app-before');diagnostics=background_save(name+'-background',session_doc,expected);client.close();command(name+'-activate',simctl+['launch',udid,APP_ID]);after=app_pid(name+'-app-after');assert before==after,(before,after);client=new_client(name+'-mcp')
 resumed=wait_tree(client,name+'-resumed-tree');selected_button(resumed,expected.title());tap(client,'Deep Links');tap_with_scroll(client,name+'-restore',RESTORE_LABEL);restored=wait_tree(client,name+'-restored-tree');selected_button(restored,expected.title());final_pid=app_pid(name+'-app-after-restore');assert before==final_pid,(before,final_pid)
 proof={'savedSelection':expected,'restoreControl':RESTORE_LABEL,'sameAppPID':before,'semanticRestorePassed':True,'timedPreferenceDiagnostics':diagnostics};save(name+'-semantic-save-restore',proof);return client,session_doc,proof,before

def terminate_relaunch(name,client):
 old=app_pid(name+'-old-app');doc=json.loads(session.read_text());client.close();command(name+'-terminate',simctl+['terminate',udid,APP_ID]);stop_runner(name+'-runner-stop',doc);command(name+'-launch',simctl+['launch',udid,APP_ID]);doc=start_runner(name+'-runner-start');fresh=app_pid(name+'-fresh-app');assert fresh!=old,(old,fresh);return new_client(name+'-mcp'),doc

def assert_heart(client,name,selected,initial_label):
 tree=wait_tree(client,name+'-before');selected_button(tree,initial_label);button=favorites_button(tree,selected)
 after=tap(client,'heart','identifier');favorites_button(after,True);selected_button(after,'Favorites')
 save(name+'-check',{'initialSelected':initial_label,'favoritesButton':button,'literalHeartMatchedByIdentifier':True});return after

save('invocation',{'ownership':str(ownership_path),'app':str(app),'commit':commit,'output':str(out),'binary':str(binary),'buildEvidence':str(build_evidence),'started':time.time(),'qualification':'Demo-only public tab-container regression on retained old CLI/runner candidate; not final Task 8 candidate validation.','transportTenPairExcluded':True,'uiTestingNavigatorReset':'Every fresh process launch intentionally starts on Landmarks; Favorites persistence is tested only across background/resume in the same process.'})
simulator_identity=command('simulator-identity',simctl+['getenv',udid,'SIMULATOR_DEVICE_NAME']).stdout.decode().strip();assert simulator_identity==ownership['name'],(simulator_identity,ownership['name'])
command('cli-version',[binary,'--version'])
command('runner-version',[binary,'runner','version','--json'])
for required in ('app-manifest.json','source-head.txt','built-source-commit.txt','app-path.txt'):assert (build_evidence/required).is_file(),required
reviewed_manifest=json.loads((build_evidence/'app-manifest.json').read_text());built_files=file_manifest(app)
assert built_files==reviewed_manifest,(built_files,reviewed_manifest)
assert (build_evidence/'source-head.txt').read_text().strip()==commit==(build_evidence/'built-source-commit.txt').read_text().strip()
assert Path((build_evidence/'app-path.txt').read_text().strip()).resolve()==app
stock_inputs=json.loads((INPUTS/'stock-inputs.json').read_text());runtime_key=runtime.split()[1].split('.')[0];stock_rows=[r for r in stock_inputs['flows'] if r['runtime']==runtime_key]
assert [Path(r['dest']).stem for r in stock_rows]==EXPECTED_FLOWS
flow_paths=sorted((project/'.maestro').glob('*.yaml'));assert [p.stem for p in flow_paths]==EXPECTED_FLOWS
for path,row in zip(flow_paths,stock_rows):assert path.resolve()==Path(row['dest']).resolve() and hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']
config=INPUTS/f'config{runtime_key}.yml';assert config.read_bytes()==(project/'grantiva.yml').read_bytes()
runner_inventory=[]
for candidate in sorted(home.rglob('grantiva-runner')):
 if candidate.is_file():runner_inventory.append({'path':str(candidate),'sha256':hashlib.sha256(candidate.read_bytes()).hexdigest()})
assert runner_inventory;save('provenance',{'ownership':ownership,'demoCommit':commit,'builtApp':str(app),'builtAppManifest':built_files,'approvedBuildEvidence':{'directory':str(build_evidence),'sourceHead':commit,'builtSourceCommit':commit,'appPath':str(app),'manifestSHA256':hashlib.sha256((build_evidence/'app-manifest.json').read_bytes()).hexdigest()},'stockInputs':stock_rows,'stockConfig':str(config),'cliSource':ownership['cliSource'],'binary':str(binary),'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),'runnerSource':ownership['runnerSource'],'runnerVersion':ownership['runnerVersion'],'runnerHome':str(home),'runnerExecutables':runner_inventory,'apiKey':'unset','sessionId':session_id,'qualification':'Demo-only fixture test using retained old CLI/runner; final Task 8 candidate and full MCP transport remain pending.'})

primary_error=None;primary_traceback=None;campaign_passed=False
try:
 assert not session.exists(),('pre-existing project session',session.read_text())
 command('terminate-before-install',simctl+['terminate',udid,APP_ID],expected=None)
 command('install',simctl+['install',udid,app])
 installed=Path(command('installed-container',simctl+['get_app_container',udid,APP_ID,'app']).stdout.decode().strip())
 built_manifest=tree_manifest(app);installed_manifest=tree_manifest(installed);save('installed-app-manifest',{'built':str(app),'installed':str(installed),'builtFiles':built_manifest,'installedFiles':installed_manifest,'allFilesMatch':built_manifest==installed_manifest});assert built_manifest==installed_manifest

 command('cold-launch',simctl+['launch',udid,APP_ID]);session_doc=start_runner('cold-runner-start');active_client=new_client('cold-mcp')
 cold=wait_tree(active_client,'cold-tree');selected_button(cold,'Landmarks');cold_button=favorites_button(cold,False);tabs=tab_contract(cold);cold_after=tap(active_client,'heart','identifier');favorites_button(cold_after,True);selected_button(cold_after,'Favorites');tab_contract(cold_after)
 checks.append({'coldLandmarksInitial':True,'realFavoritesButton':cold_button,'heartIdentifierAnnotation':True,'tabContract':tabs})

 # Background/save and reconnect MCP while the runner and app process remain unchanged.
 active_client,session_doc,favorites_defaults,favorites_pid=background_resume('resume-favorites',active_client,session_doc,'favorites')
 assert_heart(active_client,'resume-favorites',True,'Favorites')
 checks.append({'backgroundSaveResumeSameAppProcess':'Favorites','selectionRetainedInRunningApp':True,'unchangedAppPID':favorites_pid,'semanticSaveRestore':favorites_defaults})

 landmarks=tap(active_client,'Landmarks');favorites_button(landmarks,False);selected_button(landmarks,'Landmarks')
 active_client,session_doc,landmarks_defaults,landmarks_pid=background_resume('resume-landmarks',active_client,session_doc,'landmarks')
 assert_heart(active_client,'resume-landmarks',False,'Landmarks')
 checks.append({'backgroundSaveResumeSameAppProcess':'Landmarks','selectionRetainedInRunningApp':True,'unchangedAppPID':landmarks_pid,'semanticSaveRestore':landmarks_defaults})

 # UITesting intentionally clears NavigatorState at process launch. Test both pre-restart selections and require cold Landmarks, never a false persisted-Favorites claim.
 active_client,session_doc=terminate_relaunch('restart-after-favorites',active_client)
 assert_heart(active_client,'restart-after-favorites',False,'Landmarks')
 checks.append({'selectionBeforeTerminate':'Favorites','freshUITestingLaunch':'Landmarks','intentionalNavigatorReset':True})
 tap(active_client,'Landmarks');active_client,session_doc=terminate_relaunch('restart-after-landmarks',active_client)
 assert_heart(active_client,'restart-after-landmarks',False,'Landmarks')
 checks.append({'selectionBeforeTerminate':'Landmarks','freshUITestingLaunch':'Landmarks','intentionalNavigatorReset':True})

 # Stable hosting controllers must preserve the Landmarks navigation stack while switching tabs in the same process.
 tap(active_client,'Landmarks');tap(active_client,'Mountains');detail_before=wait_tree(active_client,'navigation-before-switch');assert any(n.get('label')=='Mount "Denali"' for n in nodes(detail_before)),detail_before
 tap(active_client,'heart','identifier');detail_after=tap(active_client,'Landmarks');assert any(n.get('label')=='Mount "Denali"' for n in nodes(detail_after)),detail_after
 checks.append({'inProcessTabSwitchPreservesLandmarksNavigationStack':True})
 active_client.close();active_client=None;stop_runner('pre-stock-stop',session_doc)

 stock=command('stock',[binary,'run','--no-build','--platform','ios','--simulator',udid,'--report-dir',out/'stock-report','--json'])
 stock_json=json.loads(stock.stdout);report=json.loads((out/'stock-report/report.json').read_text());assert stock_json.get('allPassed') is True and report['summary']['total']==4 and report['summary']['passed']==4 and report['summary']['failed']==0,report;assert [f['name'] for f in report['flows']]==EXPECTED_FLOWS and all(f['status']=='passed' for f in report['flows']);checks.append({'stockFlowNames':EXPECTED_FLOWS,'stockNonemptyAllPassed':True,'report':str(out/'stock-report')})
 command('post-stock-terminate',simctl+['terminate',udid,APP_ID],expected=None);command('post-stock-launch',simctl+['launch',udid,APP_ID]);session_doc=start_runner('post-stock-runner-start');active_client=new_client('selector-mcp')

 for arguments,expected in [({},"Error: Invalid argument: 'steps' is required."),({'steps':'tap'},"Error: Invalid argument: 'steps' array is required.")]:
  reply=active_client.tool('grantiva_script',arguments);assert reply['result'].get('isError') and Client.text(reply)==expected,(arguments,reply)
 empty=active_client.tool('grantiva_script',{'steps':[]});assert good(empty) and 'Final hierarchy:' in Client.text(empty),empty
 missing=active_client.tool('grantiva_tap',{'label':'No Such Selector tab-container'});assert missing['result'].get('isError') and 'Element not found' in Client.text(missing),missing
 checks.append({'missingStepsExact':True,'wrongStepsExact':True,'emptyStepsPreserved':True,'unknownSelectorPreserved':True})

 for label,annotation in [('Landmarks',None),('Favorites',None),('heart','identifier'),('Landmarks',None),('Deep Links',None),('Edit Landmark',None),('Name','placeholder'),('Cancel',None),('Landmarks',None),('Mountains',None),('Mount "Denali"',None)]:
  tap(active_client,label,annotation)
 checks.append({'labelsOrderSymbolsNavigationEnvironmentPreserved':True,'quotedLabel':True,'placeholderAnnotation':True,'identifierAnnotation':True})
 campaign_passed=True
except BaseException as error:
 primary_error=error;primary_traceback=error.__traceback__
finally:
 cleanup=[];cleanup_errors=[]
 def cleanup_step(label,operation):
  try:return operation()
  except BaseException as error:cleanup_errors.append({'step':label,'type':type(error).__name__,'message':str(error)});return None
 if active_client is not None:cleanup_step('close-active-mcp',active_client.close)
 if session.exists():
  cleanup_step('normal-runner-stop',lambda:stop_runner('final-runner-stop',json.loads(session.read_text())))
 for pid in sorted(tracked_runner):
  def clean_pid(pid=pid):
   process=host_process(pid)
   if process:
    assert str(home) in process and udid in process,(pid,process);os.kill(pid,signal.SIGINT);cleanup.append({'pid':pid,'signal':'SIGINT','exactCommand':process})
    for _ in range(40):
     if not host_process(pid):break
     time.sleep(.25)
   assert not host_process(pid),(pid,host_process(pid))
   for scoped in [Path(p) for p in global_sessions(pid)]:scoped.unlink();cleanup.append({'removedOwnedGlobalSession':str(scoped),'runnerPID':pid})
  cleanup_step('runner-pid-'+str(pid),clean_pid)
 if session.exists():
  def clean_session():
   stale=json.loads(session.read_text());assert int(stale['pid']) in tracked_runner,stale;session.unlink();cleanup.append({'removedOwnedProjectSession':str(session),'runnerPID':int(stale['pid'])})
  cleanup_step('project-session',clean_session)
 cleanup_step('app-terminate',lambda:command('cleanup-app-terminate',simctl+['terminate',udid,APP_ID],expected=None))
 def prove_app_absent():
  survivors=app_processes('cleanup-app-processes');assert not survivors,survivors
 cleanup_step('app-process-absence',prove_app_absent)
 if ownership.get('cleanupApp') is True:cleanup_step('app-uninstall',lambda:command('cleanup-app-uninstall',simctl+['uninstall',udid,APP_ID]))
 project_absent=not session.exists();globals_absent=all(not global_sessions(p) for p in tracked_runner)
 if not project_absent:cleanup_errors.append({'step':'project-session-absence','type':'AssertionError','message':str(session)})
 if not globals_absent:cleanup_errors.append({'step':'global-session-absence','type':'AssertionError','message':'tracked PID session artifacts remain'})
 try:save('cleanup',{'actions':cleanup,'errors':cleanup_errors,'succeeded':not cleanup_errors,'trackedRunnerPIDs':sorted(tracked_runner),'trackedAppPIDs':sorted(tracked_app),'projectSessionAbsent':project_absent,'globalSessionsAbsent':globals_absent,'appUninstalled':ownership.get('cleanupApp') is True,'simulatorLeftForController':True})
 except BaseException as error:cleanup_errors.append({'step':'write-cleanup-evidence','type':type(error).__name__,'message':str(error)})

if primary_error is not None:raise primary_error.with_traceback(primary_traceback)
if cleanup_errors:raise AssertionError(('cleanup failed',cleanup_errors))
assert campaign_passed
save('acceptance',{'passed':True,'cleanupSucceeded':True,'runtime':runtime,'udid':udid,'qualification':'Demo-only fixture regression; retained old CLI/runner accepted solely for this test. Final Task 8 candidate and full transport are pending.','checks':checks,'commands':len(commands)})
