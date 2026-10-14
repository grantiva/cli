from pathlib import Path
import subprocess
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5');runner=Path('/Users/kyle/Developer/maestro-runner/.worktrees/package-round4-repair');cli='/Users/kyle/.grantiva-qa/bin/grantiva';base=Path((ev/'scratch-root.txt').read_text().strip())/'batch12';base.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,q.returncode)
queries={'B-I02.4':'two booted|configured.*simulator|no-build','B-I03.3':'pre-existing capture|capture.*exiting|stale capture','B-I04.3':'alert policy|alerts_test|auto.*alert','B-I05.3':'label-based|WDAClientTests|quoted.*label','B-I06.3':'wda/keys|HTTP status|typeText','B-I07.3':'defaultLogPredicate|banner|executable','B-I08.3':'dead pid|already booted|simctl shutdown','B-I09.3':'active.*record|owner.json|capacity store','B-I10.3':'unknown model|existing.*runtime|bare ensure','B-I11.3':'stagedPathMap|junit|report rewriter','B-I12.3':'allPassed|fixture report|failed step','B-I13.3':'two schemes|one scheme|ProjectDetector','B-I14.2':'created.*delete|reserve.*capacity|simctl delete','B-I14.3':'capacity.*times out|reused.*delete|simctl delete','B-I15.3':'URLError.timedOut|not installed|runner is never','B-I16.3':'Deep Links.png|Deep%20Links|ScreenArtifactTests','B-I17.3':'TestResult.*success.*false|BuildToolsTests|configured for the test action','B-I18.3':'same.yaml|unique flow names|staging.*unique'}
for row,q in queries.items():run(row,'source-inspection',src,['rg','-n','-i',q,'Sources','Tests'])
# JSON setup failures
p=base/'i12-missing';p.mkdir();(p/'grantiva.yml').write_text('scheme: Landmarks\nbundle_id: com.example\nflows: [flow.yaml]\n');(p/'flow.yaml').write_text('appId: com.example\n---\n- launchApp\n');run('B-I12.2','missing-device',p,[cli,'run','--json','--no-build','--simulator','00000000-0000-0000-0000-000000000527'])
p=base/'i12-bad';p.mkdir();(p/'grantiva.yml').write_text('scheme: Landmarks\nscreens:\n  - name: Bad\n    path:\n      - swipe: diagonal\n');run('B-I12.2','bad-config',p,[cli,'run','--json','--no-build','--simulator','00000000-0000-0000-0000-000000000527'])
run('B-I19.1','docs',src,['sed','-n','120,145p','README.md'])
# Runner source rows and version/provenance
run('B-R01.5','runner-source',runner,['rg','-n','-i','focused|append|set-value|existing text|inputText','pkg'])
run('B-R01.6','version',src,[cli,'runner','version'])
run('B-R01.6','provenance',src,['/bin/bash','-c','git log -1 --format=%H%n%s; rg -n "runnerVersion|1.1.28-grantiva.15" Sources Package.swift'])
run('B-R02.5','runner-source',runner,['rg','-n','-i','900|520|swipe.*distance|minimum.*swipe|percentage','pkg'])
