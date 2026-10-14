from pathlib import Path
import json,re,hashlib
E=Path('findings/evidence/cov6-cli'); plan=json.load(open(E/'direct-row-batches.json'))['batches'][0]['rows']; expected={x['key']:x['expected'] for x in plan}
def text(r,l,s):return (E/r/(l+s)).read_text(errors='replace')
def cmd(r,l):return json.load(open(E/r/(l+'.command.json')))
def ex(r,l):return cmd(r,l)['exitStatus']
def valid_json(r,l):return json.loads(text(r,l,'.stdout'))
def has_all(s,vals):return all(v in s for v in vals)
checks={}
checks['CLI-001']=[ex('CLI-001','help')==0,ex('CLI-001','version')==0,text('CLI-001','version','.stdout').strip()=='2.1.0',has_all(text('CLI-001','help','.stdout'),['OVERVIEW:','The Grantiva CLI for iOS and Android developers.','build','run','record','simulator','emulator','hierarchy','ci','diff','auth','console','doctor','runner','init','mcp'])]
checks['CLI-002']=[ex('CLI-002',x)==0 for x in ['help-run','run-help','help-runner-start','runner-start-help','help-console-flags','console-flags-help']]+[text('CLI-002','help-run','.stdout')==text('CLI-002','run-help','.stdout'),text('CLI-002','help-runner-start','.stdout')==text('CLI-002','runner-start-help','.stdout'),text('CLI-002','help-console-flags','.stdout')==text('CLI-002','console-flags-help','.stdout')]
# Candidate5 smoke docs-output is the current frozen candidate's successful 172-page corpus regeneration.
smoke=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-candidate5/06-docs-output/helper')
checks['CLI-003']=[json.load(open(smoke/'acceptance.json')).get('passed') is True,json.load(open(smoke/'corpus-tests/result.json')).get('exit')==0,len(list((smoke/'help').glob('*.txt')))==172]
h=text('CLI-004','help','.stdout');checks['CLI-004']=[ex('CLI-004','help')==0,ex('CLI-004','rejected-flag')==64,not any(x in h for x in ['--auto-accept-alerts','--no-auto-accept-alerts','--wait-for-idle-timeout']),not text('CLI-004','rejected-flag','.stdout')]
b=text('CLI-005','build','.stdout');bb=text('CLI-005','build-build','.stdout');bi=text('CLI-005','build-install','.stdout');checks['CLI-005']=[all(ex('CLI-005',x)==0 for x in ['build','build-build','build-install']),has_all(bi,['--app-file','--no-build','--no-launch']),not any(x in bb for x in ['--app-file','--no-build','--no-launch']),'build (default)' in b]
c=text('CLI-006','compare','.stdout');a=text('CLI-006','approve','.stdout');checks['CLI-006']=[all(ex('CLI-006',x)==0 for x in ['capture','compare','approve']),'--capture' in c,'runs full lifecycle' in c,'[<screen-names> ...]' in a,'--platform' in a]
checks['CLI-007']=[all(ex('CLI-007',x)==0 for x in ['simulator-ensure','simulator-delete','simulator-sessions','simulator-teardown','simulator-cleanup','emulator-ensure','emulator-delete','emulator-sessions','emulator-teardown','emulator-cleanup']),has_all(text('CLI-007','simulator-ensure','.stdout'),['--boot','--no-boot','default: --boot']),has_all(text('CLI-007','emulator-teardown','.stdout'),['--serial','--all','--force']),has_all(text('CLI-007','emulator-delete','.stdout'),['--name','--force'])]
d=text('CLI-008','dump','.stdout');rec=text('CLI-008','record','.stdout');checks['CLI-008']=[all(ex('CLI-008',x)==0 for x in ['install','version','start','stop','dump','hierarchy','record']),has_all(d,['-p, --port','-f, --format','tree','json','xml','--udid']),('--duration' in rec and 'required' in rec.lower())]
con=text('CLI-009','console','.stdout');checks['CLI-009']=[ex('CLI-009','console')==0,has_all(con,['flags','featureflags','envs','analytics','devices','apps','claims','vrt','releases','feedback','support','webhooks','alerts','keys','team','audit','org','open']),text('CLI-009','flags','.stdout')==text('CLI-009','featureflags','.stdout')]
checks['CLI-010']=[all(ex('CLI-010',x)==64 for x in ['run-bogus','doctor-bogus']),all(not text('CLI-010',x,'.stdout') for x in ['run-bogus','doctor-bogus']),all('Usage:' in text('CLI-010',x,'.stderr') for x in ['run-bogus','doctor-bogus'])]
checks['CLI-123']=[has_all(text('CLI-123','help','.stdout'),['WDA','UIAutomator2 on Android'])]
checks['CLI-124']=[has_all(text('CLI-124','help','.stdout'),['DISCUSSION:','without a session','--project-dir','--platform'])]
q=text('CLI-125','help','.stdout');checks['CLI-125']=[has_all(q,['/tmp/grantiva-sessions','newest','--udid','--timeout','default: 60','xml','json','--json'])]
for row,label in [('CLI-011','json'),('CLI-012','quiet'),('CLI-013','verbose')]:
 d=valid_json(row,label); checks[row]=[isinstance(d,list),all(x.get('status') in ['ok','warning','error'] for x in d),ex(row,label) in [0,1]]
d=valid_json('CLI-011','json-invalid-devdir-ios');checks['CLI-011'] += [ex('CLI-011','json-invalid-devdir-ios')==1,any(x.get('status')=='error' and x.get('name','').startswith('Xcode') for x in d),text('CLI-011','json-invalid-devdir-ios','.stderr')=='']
checks['CLI-013'] += [bool(text('CLI-013','verbose','.stderr')),bool(re.search(r'\d{4}-\d\d-\d\d',text('CLI-013','verbose','.stderr')))]
checks['CLI-014']=[ex('CLI-014','redirected')==0,b'\x1b' not in (E/'CLI-014/redirected.stdout').read_bytes(),b'\x1b' not in (E/'CLI-014/no-color-tty.stdout').read_bytes()]
for row in ['CLI-015','CLI-016']:
 checks[row]=[all(ex(row,x)==0 for x in ['plain','quiet','verbose']),all(isinstance(valid_json(row,x),(dict,list)) for x in ['plain','quiet','verbose'])]
checks['CLI-017']=[ex('CLI-017','text')==0,ex('CLI-017','json')==0,bool(text('CLI-017','text','.stdout').strip()),isinstance(valid_json('CLI-017','json'),dict)]
checks['CLI-019']=[ex('CLI-019','doctor-ios')==1,isinstance(valid_json('CLI-019','doctor-ios'),list),text('CLI-019','doctor-ios','.stderr')=='',ex('CLI-019','sim-teardown')!=0,text('CLI-019','sim-teardown','.stdout')=='',ex('CLI-019','diff-compare')!=0,text('CLI-019','diff-compare','.stdout')=='',ex('CLI-019','run-empty')!=0,isinstance(valid_json('CLI-019','run-empty'),dict),valid_json('CLI-019','run-empty').get('allPassed') is False]
checks['CLI-020']=[text('CLI-020','normal','.stdout')==text('CLI-020','quiet','.stdout'),ex('CLI-020','normal')==ex('CLI-020','quiet')]
checks['CLI-021']=[text('CLI-021','normal','.stdout')==text('CLI-021','verbose','.stdout'),len(text('CLI-021','verbose','.stderr'))>len(text('CLI-021','normal','.stderr'))]
checks['CLI-126']=[ex('CLI-126','install')==0,ex('CLI-126','stop')==0,isinstance(valid_json('CLI-126','install'),dict),isinstance(valid_json('CLI-126','stop'),dict)]
init=Path('/private/tmp/grantiva-candidate5-coverage-qjr26z3g/cli-scratch/batch1/ios-init/grantiva.yml'); checks['CLI-023']=[ex('CLI-023','doctor')==0,ex('CLI-023','init')==0,init.exists(),'scheme:' in init.read_text()]
ledger=[]
for i,row in enumerate(plan,1):
 key=row['key']; ok=all(checks.get(key,[])) and bool(checks.get(key)); grade='PASS' if ok else 'FAIL'
 refs=[str(p.relative_to(E)) for p in sorted((E/key).glob('*.command.json'))]
 if key=='CLI-003':refs += [str(smoke/'acceptance.json'),str(smoke/'corpus-tests/result.json')]
 body=f"# {key} candidate5 clause assessment\n\nVerdict: **{grade}**.\n\nExpected: {expected[key]}\n\nClause checks: {checks.get(key)}. Evidence commands: " + ', '.join(f'`{x}`' for x in refs) + '.\n'
 (E/key/'verdict.md').write_text(body)
 ledger.append({'directOrdinal':i,'key':key,'grade':grade,'evidence':str((E/key/'verdict.md').relative_to(E)),'checks':checks.get(key)})
(E/'results-ledger.json').write_text(json.dumps({'candidateManifestSHA256':'191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c','session':'candidate5-cli','rows':ledger},indent=2)+'\n')
print(json.dumps({'PASS':sum(x['grade']=='PASS' for x in ledger),'FAIL':sum(x['grade']=='FAIL' for x in ledger),'fails':[x['key'] for x in ledger if x['grade']=='FAIL']}))
