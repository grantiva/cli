"""Controller docs/output smoke against the frozen candidate; no device mutations."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,time,shutil
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
r=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression');e=r/'findings/evidence/completion-candidate5'
c=json.loads((e/'candidate.json').read_text());state=json.loads((e/'initial-state.json').read_text());s=Path(state['scratch']);src=Path(c['cli']['repoPath']);b=Path(c['cli']['binary']['path']);o=Path(a.output).resolve();o.mkdir(parents=True,exist_ok=False)
def save(path,data):path.write_text(json.dumps(data,indent=2)+'\n')
assert hashlib.sha256(b.read_bytes()).hexdigest()==c['cli']['binary']['sha256']
env=os.environ.copy();env.pop('GRANTIVA_API_KEY',None);env.pop('GRANTIVA_PLATFORM',None);env.update(GRANTIVA_RUNNER_HOME=state['runnerHome'],MAESTRO_RUNNER_HOME=state['runnerHome'],GRANTIVA_SESSION_ID='completion-candidate5')
def run(label,argv,cwd=s,extra=None):
 d=o/label;d.mkdir(parents=True,exist_ok=False);v={**env,**(extra or {})};m={'argv':list(map(str,argv)),'cwd':str(cwd),'start':time.time(),'apiEnvironmentUnset':True,'runnerHome':v['GRANTIVA_RUNNER_HOME'],'session':'completion-candidate5'};save(d/'start.json',m)
 with (d/'stdout.log').open('wb') as so,(d/'stderr.log').open('wb') as se:p=subprocess.run(m['argv'],cwd=cwd,env=v,stdout=so,stderr=se,timeout=1200)
 m.update(exit=p.returncode,end=time.time());save(d/'result.json',m);assert p.returncode==0,(label,p.returncode);return (d/'stdout.log').read_text()
helpdir=o/'help';helpdir.mkdir();queue=[[]];seen=set();rows=[]
while queue:
 path=queue.pop(0);key='_'.join(path) or 'grantiva';assert key not in seen and len(path)<8;seen.add(key)
 text=run('help-commands/'+key,[b,*path,'--help']);(helpdir/(key+'.txt')).write_text(text);rows.append({'path':path,'file':key+'.txt','sha256':hashlib.sha256(text.encode()).hexdigest()})
 section=False
 for line in text.splitlines():
  if line=='SUBCOMMANDS:':section=True;continue
  if section and line and not line.startswith(' '):section=False
  if section:
   match=re.match(r'^  ([a-z][a-z0-9-]*)(?:,|\s|$)',line)
   if match:queue.append(path+[match.group(1)])
assert len(rows)==172,len(rows);save(helpdir/'manifest.json',rows)
for name in ['grantiva.txt','runner_start.txt','run.txt','doctor.txt']:assert (helpdir/name).is_file()
terms={'README.md':['legacy baseline','percent-encoded','ambiguous `%`','migration on approval'],'docs/mcp.md':['ISO 8601','1970-01-01T00:00:00Z','label → identifier → placeholder','runnerSessionStopped','leftoverProcesses','reapedProcesses']}
inspected=[]
for name,needles in terms.items():
 text=(src/name).read_text()
 for needle in needles:
  assert needle in text,(name,needle);inspected.append({'file':name,'term':needle,'lines':[i for i,line in enumerate(text.splitlines(),1) if needle in line]})
save(o/'docs-inspection.json',{'sourceSHA':c['cli']['mergedSHA'],'publicCompatibilityTerms':inspected})
normal_text=run('doctor-text',[b,'doctor']);normal_json=json.loads(run('doctor-json',[b,'doctor','--json']))
amb=s/'doctor-ambiguous-project';assert (amb/'App.xcodeproj').is_dir() and (amb/'settings.gradle.kts').is_file() and not list(amb.glob('grantiva*'))
amb_text=run('doctor-ambiguous-text',[b,'doctor'],amb);amb_json=json.loads(run('doctor-ambiguous-json',[b,'doctor','--json'],amb))
platform=next(x for x in amb_json if x['name']=='Platform');assert platform['section']=='Advisory' and platform['status']=='warning' and 'Found both an Xcode project and Gradle settings' in platform['message'] and platform['message'] in amb_text
booted=next(x for x in normal_json if x['name']=='Booted Simulator');assert booted['message'] in normal_text
unit=s/'corpus-test-home';unit.mkdir();assert not list(unit.iterdir())
test=run('corpus-tests',['swift','test','-c','release','--scratch-path',s/'swift-build-scratch','--filter','HelpCorpusTests|DocsContractTests'],src,{'GRANTIVA_RUNNER_HOME':str(unit),'MAESTRO_RUNNER_HOME':str(unit)})
assert 'Executed 16 tests, with 0 failures' in test and not list(unit.iterdir())
published=o/'published-help';published.mkdir()
for row in rows:shutil.copy2(helpdir/row['file'],published/row['file'])
save(o/'acceptance.json',{'passed':True,'candidateManifestSHA256':hashlib.sha256((e/'candidate.json').read_bytes()).hexdigest(),'helpPages':len(rows),'corpusTests':16,'corpusFailures':0,'freshUnitHomeEmptyAfter':True,'doctorTextJSONOwnershipAgreement':True,'publicMigrationNotesInspected':True,'ambiguousPlatformAdvisory':platform,'ambiguousTextJSONExitZero':True})
print('Docs/output smoke passed')
