#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,shutil
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch3tail';s.mkdir(exist_ok=True);demo=Path('/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2')
def cp(name,sub):p=s/name;subprocess.run(['cp','-cR',str(demo/sub),str(p)],check=True) if not p.exists() else None;return p
def run(row,label,cwd,args,timeout='120'):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout',timeout,'--',*args],cwd=root);return {'row':row,'label':label,'exit':q.returncode}
r=[];p=s/'060';p.mkdir(exist_ok=True);r+=[run('CLI-060','teardown',p,[b,'simulator','teardown','--session-id','X','--udid','00000000-0000-0000-0000-000000000527'])]
p=cp('ios','ios');r+=[run('CLI-166','ci-json',p,[b,'ci','run','--json'])]
p=cp('android','android')
for label,args in [('headless',['--headless']),('emulator',['--emulator','cov5-android']),('module',['--module','app','--variant','freeDebug']),('derived',['--derived-data-path','x'])]:r+=[run('CLI-167',label,p,[b,'ci','run','--platform','android',*args])]
p=cp('ios168','ios')
for label,args in [('derived',['--derived-data-path','x']),('named',['--scheme','Landmarks (UI Testing)','--simulator','cov5-ios-1'])]:r+=[run('CLI-168',label,p,[b,'ci','run',*args])]
p=cp('ios169','ios');r+=[run('CLI-169','settings',p,[b,'run','--allow-device-settings']),run('CLI-169','headless',p,[b,'run','--headless'])]
(ev/'batch3-tail-execution.json').write_text(json.dumps(r,indent=2)+'\n')
