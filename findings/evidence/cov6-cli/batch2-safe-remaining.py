#!/usr/bin/env python3
from pathlib import Path
import subprocess,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch2-new';s.mkdir(exist_ok=True);demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2/ios')
def fresh(name,demo_copy=False):
 p=s/name
 if not p.exists():
  if demo_copy:subprocess.run(['cp','-cR',str(demo),str(p)],check=True)
  else:p.mkdir()
 return p
def write(p,n,t): (p/n).write_text(t)
def run(row,label,cwd,argv):
 d=ev/(row+'-rerun-1');d.mkdir(exist_ok=True);cp=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);return {'row':row,'label':label,'exit':cp.returncode,'cwd':str(cwd),'argv':argv}
out=[]
p=fresh('028');(p/'.maestro').mkdir(exist_ok=True);out+=[run('CLI-028','run',p,[b,'run']),run('CLI-028','diff',p,[b,'diff','capture'])]
p=fresh('031');write(p,'grantiva.yml','screens: []\n');write(p,'grantiva-android.yml','screens: []\n');out+=[run('CLI-031','run-android',p,[b,'run','--platform','android']),run('CLI-031','doctor-android',p,[b,'doctor','--platform','android']),run('CLI-031','run-ios-env',p,['/usr/bin/env','GRANTIVA_PLATFORM=ios',b,'run']),run('CLI-031','doctor-ios-env',p,['/usr/bin/env','GRANTIVA_PLATFORM=ios',b,'doctor'])]
p=fresh('127');write(p,'settings.gradle.kts','rootProject.name = "Trim"\n');out+=[run('CLI-127','trimmed',p,['/usr/bin/env','GRANTIVA_PLATFORM= Android ',b,'doctor']),run('CLI-127','empty',p,['/usr/bin/env','GRANTIVA_PLATFORM=',b,'doctor'])]
p=fresh('038',True);write(p,'grantiva.yml','# comments only\n\n');out+=[run('CLI-038','run',p,[b,'run'])]
p=fresh('039',True);write(p,'grantiva.yml','schem: Landmarks\nsimulator: cov5-ios-26\nscreens:\n  screen: Home\n');out+=[run('CLI-039','run',p,[b,'run']),run('CLI-039','doctor',p,[b,'doctor'])]
p=fresh('044',True);write(p,'grantiva.yml','scheme: Landmarks\nsimulator: cov5-ios-26\nflows: []\n');out+=[run('CLI-044','run',p,[b,'run','--report-dir','out','--ready-file','out.ready'])]
p=fresh('045');write(p,'settings.gradle.kts','rootProject.name = "Flags"\n');out+=[run('CLI-045','run',p,[b,'run','--device','emulator-5554','--emulator','cov5-android'])]
(ev/'batch2-part2-execution.json').write_text(json.dumps(out,indent=2)+'\n')
