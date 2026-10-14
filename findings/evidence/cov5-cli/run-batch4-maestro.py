#!/usr/bin/env python3
from pathlib import Path
import subprocess,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch4-maestro';s.mkdir(exist_ok=True);u='00000000-0000-0000-0000-000000000527'
def run(row,label,p):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(p),'--timeout','120','--',b,'diff','capture','--platform','ios','--simulator',u,'--no-build'],cwd=root);return {'row':row,'label':label,'exit':q.returncode}
def fixture(name,steps):
 p=s/name;p.mkdir(exist_ok=True);(p/'grantiva.yml').write_text('appId: com.example.app\n---\n'+steps+'\n- takeScreenshot: Done\n');return p
cases={'tapOn':'- tapOn: X','doubleTapOn':'- doubleTapOn: X','longPressOn':'- longPressOn: X','inputText':'- inputText: hello','assertVisible':'- assertVisible: X','assertNotVisible':'- assertNotVisible: X','swipe-direction':'- swipe:\n    direction: UP','swipe-from':'- swipe:\n    from: 10%,20%\n    to: 80%,90%','swipe-start-end':'- swipe:\n    start: 10%,20%\n    end: 80%,90%\n    duration: 500','scroll':'- scroll','scrollUntilVisible':'- scrollUntilVisible:\n    element:\n      text: X\n    direction: DOWN','runFlow-string':'- runFlow: sub.yaml','runFlow-map':'- runFlow:\n    file: sub.yaml','extended-visible':'- extendedWaitUntil:\n    visible: X','extended-not':'- extendedWaitUntil:\n    notVisible: X','waitAnimation':'- waitForAnimationToEnd','launchApp':'- launchApp','stopApp':'- stopApp','killApp':'- killApp'}
r=[]
for n,v in cases.items():
 p=fixture('063-'+n,v)
 if 'runFlow' in n:(p/'sub.yaml').write_text('- tapOn: Sub\n')
 r.append(run('CLI-063',n,p))
p=fixture('065','- launchApp\n- tapOn: X\n- back\n- setPermissions:\n    camera: allow\n- evalScript: x\n- pressKey: HOME\n- openLink: https://example.com');r.append(run('CLI-065','unsupported',p))
p=fixture('067','- takeScreenshot: One\n- tapOn: X');r.append(run('CLI-067','two-screens',p))
for n,v in [('string','- runFlow: sub.yaml'),('map','- runFlow:\n    file: sub.yaml')]:
 p=fixture('068-'+n,v);(p/'sub.yaml').write_text('- tapOn: Sub\n');r.append(run('CLI-068',n,p))
p=fixture('135','- swipe:\n    direction: UP\n- extendedWaitUntil:\n    visible: X\n- waitForAnimationToEnd');r.append(run('CLI-135','forms',p))
(ev/'batch4-maestro-execution.json').write_text(json.dumps(r,indent=2)+'\n')
