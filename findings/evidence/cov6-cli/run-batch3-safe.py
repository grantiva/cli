#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,os
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch3';s.mkdir(exist_ok=True);demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2/ios')
def d(n):p=s/n;p.mkdir(exist_ok=True);return p
def run(row,label,cwd,argv):
 o=ev/(row+'-run-1');o.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(o),label,str(cwd),'--timeout','180','--',*argv],cwd=root);return {'row':row,'label':label,'exit':q.returncode,'cwd':str(cwd),'argv':argv}
r=[]
p=d('047');(p/'grantiva.yml').write_text('scheme: Landmarks\nsimulator: 00000000-0000-0000-0000-000000000527\nscreens:\n  - name: Diag\n    path:\n      - swipe: diagonal\n');r+=[run('CLI-047','capture',p,[b,'diff','capture','--platform','ios','--simulator','00000000-0000-0000-0000-000000000527','--no-build'])]
p=d('050');
for i,x in enumerate(['NOEQUALS','=v','A B=1','1A=x']):r+=[run('CLI-050',f'env-{i}',p,[b,'run','--env',x])]
p=d('051');(p/'existing').mkdir(exist_ok=True);r+=[run('CLI-051','run',p,[b,'run','--ready-file',str(p/'existing')])]
for row in ['CLI-052','CLI-053']:
 p=d(row);ready=p/'x.ready';
 if row=='CLI-052':ready.write_text('{"status":"passed"}\n')
 r+=[run(row,'run',p,[b,'run','--ready-file',str(ready)])]
p=d('054');q=p/'locked';q.mkdir(exist_ok=True);q.chmod(0o500);r+=[run('CLI-054','run',p,[b,'run','--ready-file',str(q/'x.ready')])];q.chmod(0o700)
p=d('055');r+=[run('CLI-055','run',p,[b,'run','--snapshot','bogus'])]
p=d('056');r+=[run('CLI-056','abc',p,[b,'run','--timeout','abc']),run('CLI-056','negative',p,[b,'run','--timeout','-1'])]
for row,args in [('CLI-129',['--timeout','5']),('CLI-129',['--timeout','5','--ready-file',str(d('129')/'r.ready')]),('CLI-130',['--timeout','5','--keep-alive']),('CLI-131',['--logs-level','warning'])]:r+=[run(row,'run-'+str(len(r)),d(row.split('-')[-1]),[b,'run',*args])]
p=d('057');(p/'settings.gradle.kts').write_text('rootProject.name="X"\n');r+=[run('CLI-057','run',p,[b,'run','--platform','android','--application-id','not valid'])]
p=d('058');r+=[run('CLI-058','teardown',p,[b,'simulator','teardown','--udid','','--force'])]
p=d('059');r+=[run('CLI-059','bad-udid',p,[b,'simulator','teardown','--udid','not-a-udid-at-all','--force']),run('CLI-059','empty-session',p,[b,'simulator','teardown','--session-id',''])]
p=d('062');r+=[run('CLI-062','teardown',p,[b,'simulator','teardown'])]
p=d('132');(p/'App.xcodeproj').mkdir(exist_ok=True);r+=[run('CLI-132','run',p,[b,'run','--device','emulator-5554'])]
p=d('133');r+=[run('CLI-133','run',p,[b,'run','--flow','missing.yaml'])]
p=d('134i');(p/'App.xcodeproj').mkdir(exist_ok=True)
for label,args in [('build',['build','build','--variant','x']),('ci',['ci','run','--device','emulator-5554']),('runner',['runner','start','--application-id','a.b'])]:r+=[run('CLI-134','ios-'+label,p,[b,*args])]
p=d('134a');(p/'settings.gradle.kts').write_text('rootProject.name="X"\n')
for label,args in [('install',['build','install','--bundle-id','x']),('diff',['diff','capture','--scheme','X']),('runner',['runner','start','--simulator','X'])]:r+=[run('CLI-134','android-'+label,p,[b,*args])]
p=d('165');(p/'grantiva.yml').write_text('screens: []\n');(p/'grantiva-android.yml').write_text('screens: []\n');r+=[run('CLI-165','install',p,[b,'build','install'])]
(ev/'batch3-safe-execution.json').write_text(json.dumps(r,indent=2)+'\n')
