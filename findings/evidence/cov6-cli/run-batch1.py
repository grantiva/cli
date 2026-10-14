#!/usr/bin/env python3
from pathlib import Path
import json,subprocess,shutil,os
wt=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli'); ev=wt/'findings/evidence/cov6-cli'; cap=ev/'capture-one.rb'; cli='/Users/kyle/.grantiva-qa/bin/grantiva'; scratch=Path('/private/tmp/grantiva-candidate5-coverage-qjr26z3g/cli-scratch/batch1'); scratch.mkdir(parents=True,exist_ok=True)
results=[]
def run(row,label,cwd,args,timeout=120):
 d=ev/row; d.mkdir(exist_ok=True)
 q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout',str(timeout),'--',*args],cwd=wt)
 results.append({'row':row,'label':label,'collectorExit':q.returncode,'cwd':str(cwd),'argv':args})
# help surface
run('CLI-001','help',wt,[cli,'--help']);run('CLI-001','version',wt,[cli,'--version'])
for label,a in [('help-run',['help','run']),('run-help',['run','--help']),('help-runner-start',['help','runner','start']),('runner-start-help',['runner','start','--help']),('help-console-flags',['help','console','flags']),('console-flags-help',['console','flags','--help'])]:run('CLI-002',label,wt,[cli,*a])
script=ev/'CLI-003/regenerate-help.sh'; script.parent.mkdir(exist_ok=True); shutil.copy2('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli/findings/evidence/cov5-cli/CLI-003-rerun-2/regenerate-help.sh',script)
run('CLI-003','regenerate',wt,['/bin/bash',str(script),str(wt/'findings/help'),str(scratch/'help-pages')],1200)
run('CLI-004','help',wt,[cli,'run','--help']);run('CLI-004','rejected-flag',wt,[cli,'run','--wait-for-idle-timeout','5'])
for label,a in [('build',['build','--help']),('build-build',['build','build','--help']),('build-install',['build','install','--help'])]:run('CLI-005',label,wt,[cli,*a])
for sub in ['capture','compare','approve']:run('CLI-006',sub,wt,[cli,'diff',sub,'--help'])
for family,subs in [('simulator',['ensure','delete','sessions','teardown','cleanup']),('emulator',['ensure','delete','sessions','teardown','cleanup'])]:
 for sub in subs:run('CLI-007',family+'-'+sub,wt,[cli,family,sub,'--help'])
for label,a in [('install',['runner','install','--help']),('version',['runner','version','--help']),('start',['runner','start','--help']),('stop',['runner','stop','--help']),('dump',['runner','dump-hierarchy','--help']),('hierarchy',['hierarchy','--help']),('record',['record','--help'])]:run('CLI-008',label,wt,[cli,*a])
run('CLI-009','console',wt,[cli,'console','--help']);run('CLI-009','flags',wt,[cli,'console','flags','--help']);run('CLI-009','featureflags',wt,[cli,'console','featureflags','--help'])
run('CLI-010','run-bogus',wt,[cli,'run','--bogus']);run('CLI-010','doctor-bogus',wt,[cli,'doctor','--bogus'])
run('CLI-123','help',wt,[cli,'runner','start','--help']);run('CLI-124','help',wt,[cli,'mcp','--help']);run('CLI-125','help',wt,[cli,'hierarchy','--help'])
# structured output
for row,label,args in [('CLI-011','json',[cli,'doctor','--json']),('CLI-011','json-invalid-devdir',['/usr/bin/env','DEVELOPER_DIR=/nonexistent',cli,'doctor','--json']),('CLI-012','quiet',[cli,'doctor','--json','--quiet']),('CLI-013','verbose',[cli,'doctor','--json','--verbose'])]:run(row,label,wt,args,300)
run('CLI-014','redirected',wt,[cli,'doctor'],300);run('CLI-014','no-color-tty',wt,['/usr/bin/script','-q','/dev/null','/usr/bin/env','NO_COLOR=1',cli,'doctor'],300)
for row,fam in [('CLI-015','simulator'),('CLI-016','emulator')]:
 for mode in ['plain','quiet','verbose']:
  extra=[] if mode=='plain' else ['--'+mode]
  run(row,mode,wt,[cli,fam,'sessions','--json',*extra])
run('CLI-017','text',wt,[cli,'runner','version']);run('CLI-017','json',wt,[cli,'runner','version','--json'])
empty=scratch/'empty';empty.mkdir(exist_ok=True)
run('CLI-019','doctor',['/tmp'] if False else wt,['/usr/bin/env','DEVELOPER_DIR=/nonexistent',cli,'doctor','--json'],300)
run('CLI-019','sim-teardown',empty,[cli,'simulator','teardown','--json']);run('CLI-019','diff-compare',empty,[cli,'diff','compare','--json']);run('CLI-019','run-empty',empty,[cli,'run','--json'])
run('CLI-020','normal',wt,['/usr/bin/env','DEVELOPER_DIR=/nonexistent',cli,'doctor','--json'],300);run('CLI-020','quiet',wt,['/usr/bin/env','DEVELOPER_DIR=/nonexistent',cli,'doctor','--json','--quiet'],300)
run('CLI-021','normal',wt,[cli,'doctor','--json'],300);run('CLI-021','verbose',wt,[cli,'doctor','--json','--verbose'],300)
run('CLI-126','install',wt,[cli,'runner','install','--json'],300);run('CLI-126','stop',wt,[cli,'runner','stop','--json'],300)
for kind in ['doctor','init']:
 p=scratch/f'ios-{kind}';p.mkdir();(p/'Fixture.xcodeproj').mkdir();run('CLI-023',kind,p,[cli,kind])
(ev/'batch1-execution.json').write_text(json.dumps(results,indent=2)+'\n')
