#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,os
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch5';s.mkdir(exist_ok=True);demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2')
def new(n,src=None):p=s/n;subprocess.run(['cp','-cR',str(src),str(p)],check=True) if src and not p.exists() else p.mkdir(exist_ok=True) if not p.exists() else None;return p
def run(row,label,cwd,argv,env=None):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);cmd=['ruby',str(cap),str(d),label,str(cwd),'--timeout','180','--'];
 if env:cmd+=['/usr/bin/env',*env]
 cmd+=argv;q=subprocess.run(cmd,cwd=root);return {'row':row,'label':label,'exit':q.returncode,'argv':cmd}
r=[];p=new('empty')
r+=[run('CLI-086','text',p,[b,'runner','stop']),run('CLI-086','json',p,[b,'runner','stop','--json']),run('CLI-087','dump',p,[b,'runner','dump-hierarchy']),run('CLI-088','hierarchy',p,[b,'hierarchy'])]
r+=[run('CLI-139','timeout',p,[b,'hierarchy','--timeout','0']),run('CLI-139','conflict',p,[b,'hierarchy','--json','--format','xml']),run('CLI-139','yaml',p,[b,'hierarchy','--format','yaml']),run('CLI-140','conflict',p,[b,'runner','dump-hierarchy','--json','--format','tree']),run('CLI-140','bogus',p,[b,'runner','dump-hierarchy','--format','bogus'])]
p=new('141');r+=[run('CLI-141','install',p,[b,'runner','install'],['GRANTIVA_RUNNER_HOME=rh','MAESTRO_RUNNER_HOME=rh'])]
p=new('142');subprocess.run(['cp','-c',b,str(p/'grantiva')],check=True);subprocess.run(['cp','-cR','/private/tmp/grantiva-completion-candidate4-x_i_t3pq/previous-qa-candidate3/grantiva_GrantivaCore.bundle',str(p/'grantiva_GrantivaCore.bundle')],check=True);r+=[run('CLI-142','install',p,[str(p/'grantiva'),'runner','install'])]
p=new('ios',demo/'ios');p2=new('android',demo/'android');r+=[run('CLI-091','ci',p,[b,'ci','run']),run('CLI-108','ci',p2,[b,'ci','run','--platform','android'])]
r+=[run('CLI-101','record',p2,[b,'record','--platform','android','--duration','200']),run('CLI-102','record',p,[b,'record','--duration','2','--frames-at','a,b']),run('CLI-103','record',p,[b,'record']),run('CLI-143','record',p,[b,'record','--duration','0'])]
r+=[run('CLI-144','ios-mp4',p,[b,'record','--duration','2','--output','a.mp4']),run('CLI-144','android-mov',p2,[b,'record','--platform','android','--duration','2','--output','a.mov']),run('CLI-144','extensionless',p,[b,'record','--duration','2','--output','a'])]
r+=[run('CLI-145','ios-emulator',p,[b,'record','--duration','2','--emulator','X']),run('CLI-145','ios-device',p,[b,'record','--duration','2','--device','X']),run('CLI-145','android-simulator',p2,[b,'record','--platform','android','--duration','2','--simulator','X']),run('CLI-145','android-mutual',p2,[b,'record','--platform','android','--duration','2','--device','a','--emulator','b'])]
p3=new('146',demo/'ios');
for n in ('grantiva.yml','grantiva.yaml'):
 q=p3/n;q.unlink() if q.exists() else None
r+=[run('CLI-146','record',p3,[b,'record','--duration','2'])]
r+=[run('CLI-104','teardown',p,[b,'emulator','teardown']),run('CLI-147','mutual',p,[b,'emulator','teardown','--serial','emulator-5598','--all']),run('CLI-147','udid',p,[b,'emulator','teardown','--serial','00000000-0000-0000-0000-000000000527'])]
r+=[run('CLI-148','ensure',p,[b,'emulator','ensure']),run('CLI-149','emulator',p,[b,'emulator','delete']),run('CLI-149','simulator',p,[b,'simulator','delete']),run('CLI-105','ensure',p,[b,'simulator','ensure'])]
p4=new('diff');r+=[run('CLI-106','approve',p4,[b,'diff','approve']),run('CLI-106','compare',p4,[b,'diff','compare'])]
p5=new('150');c=p5/'.grantiva/captures';c.mkdir(parents=True,exist_ok=True);(c/'Home.png').write_bytes(b'fake');r+=[run('CLI-150','approve',p5,[b,'diff','approve','NoSuchScreen'])]
p6=new('151');(p6/'grantiva.yml').write_text('scheme: Landmarks\nsimulator: 00000000-0000-0000-0000-000000000527\n');r+=[run('CLI-151','capture',p6,[b,'diff','capture','--no-build'])]
r+=[run('CLI-107','build',p2,[b,'build','build','--platform','android','--derived-data-path','x'])]
(ev/'batch5-execution.json').write_text(json.dumps(r,indent=2)+'\n')
