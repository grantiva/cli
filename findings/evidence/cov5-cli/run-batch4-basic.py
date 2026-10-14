#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,os
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch4';s.mkdir(exist_ok=True);demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2')
def new(n,src=None):p=s/n;subprocess.run(['cp','-cR',str(src),str(p)],check=True) if src and not p.exists() else p.mkdir(exist_ok=True) if not p.exists() else None;return p
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','180','--',*argv],cwd=root);return {'row':row,'label':label,'exit':q.returncode}
r=[];p=new('171');r+=[run('CLI-171','quiet',p,[b,'mcp','--quiet']),run('CLI-171','verbose',p,[b,'mcp','--verbose'])]
p=new('069',demo/'ios');
for n in ('grantiva.yml','grantiva.yaml'):
 q=p/n;q.unlink() if q.exists() else None
r+=[run('CLI-069','init',p,[b,'init'])]
p=new('070');(p/'settings.gradle.kts').write_text('rootProject.name="X"\n');r+=[run('CLI-070','init',p,[b,'init'])]
p=new('071');(p/'App.xcodeproj').mkdir(exist_ok=True);(p/'settings.gradle.kts').write_text('rootProject.name="X"\n');r+=[run('CLI-071','init',p,[b,'init'])]
p=new('072');r+=[run('CLI-072','init',p,[b,'init'])]
p=new('073',demo/'ios');
for n in ('grantiva.yml','grantiva.yaml'):
 q=p/n;q.unlink() if q.exists() else None
r+=[run('CLI-073','init',p,[b,'init','--scheme','Landmarks','--bundle-id','com.kylebrowning.Landmarks'])]
p=new('074');(p/'settings.gradle.kts').write_text('rootProject.name="X"\n');r+=[run('CLI-074','init',p,[b,'init','--platform','android','--application-id','com.kylebrowning.landmarks'])]
p=new('075');r+=[run('CLI-075','first',p,[b,'init']),run('CLI-075','second',p,[b,'init'])]
for label,args in [('android-scheme',['--platform','android','--scheme','X']),('ios-appid',['--platform','ios','--application-id','a.b'])]:p=new('076'+label);r+=[run('CLI-076',label,p,[b,'init',*args])]
p=new('077');r+=[run('CLI-077','init',p,[b,'init','--json'])]
p=new('136');r+=[run('CLI-136','init',p,[b,'init','--scheme','X'])]
p=new('doctor');r+=[run('CLI-078','doctor',p,[b,'doctor','--platform','ios']),run('CLI-079','doctor',p,[b,'doctor','--platform','android']),run('CLI-080','root-fallback',p,['/usr/bin/env','-u','ANDROID_HOME','ANDROID_SDK_ROOT=/Users/kyle/Library/Android/sdk',b,'doctor','--platform','android']),run('CLI-080','home-fallback',p,['/usr/bin/env','-u','ANDROID_HOME','-u','ANDROID_SDK_ROOT',b,'doctor','--platform','android']),run('CLI-081','text',p,['/usr/bin/env','DEVELOPER_DIR=/nonexistent',b,'doctor']),run('CLI-081','json',p,['/usr/bin/env','DEVELOPER_DIR=/nonexistent',b,'doctor','--json']),run('CLI-082','android-home',p,['/usr/bin/env','ANDROID_HOME=/nonexistent',b,'doctor','--platform','android']),run('CLI-082','android-sdk-root',p,['/usr/bin/env','-u','ANDROID_HOME','ANDROID_SDK_ROOT=/nonexistent',b,'doctor','--platform','android'])]
p=new('137');(p/'grantiva-android.yml').write_text('module: app\nscreens:\n  - name: X\n    path:\n  bad\n');r+=[run('CLI-137','doctor',p,[b,'doctor','--platform','android'])]
p=new('138',demo/'android');r+=[run('CLI-138','doctor',p,[b,'doctor','--platform','android'])]
r+=[run('CLI-084','first',root,[b,'runner','install']),run('CLI-084','second',root,[b,'runner','install']),run('CLI-085','version',root,[b,'runner','version'])]
(ev/'batch4-basic-execution.json').write_text(json.dumps(r,indent=2)+'\n')
