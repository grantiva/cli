#!/usr/bin/env python3
from pathlib import Path
import subprocess,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';b='/Users/kyle/.grantiva-qa/bin/grantiva';uuid='00000000-0000-0000-0000-000000000527';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch2-resolved';s.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/(row+'-rerun-1');d.mkdir(exist_ok=True);return subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root).returncode
for row in ['CLI-027','CLI-029','CLI-046']:run(row,'simulator-inventory',root,['xcrun','simctl','list','devices','--json'])
p=s/'027';(p/'.maestro').mkdir(parents=True,exist_ok=True);(p/'.maestro/flow.yaml').write_text('appId: com.kylebrowning.Landmarks\n---\n- takeScreenshot: Home\n');run('CLI-027','run',p,[b,'run','--platform','ios','--simulator',uuid,'--no-build']);run('CLI-027','diff',p,[b,'diff','capture','--platform','ios','--simulator',uuid,'--no-build'])
p=s/'029';p.mkdir(exist_ok=True);(p/'grantiva.yml').write_text('appId: com.kylebrowning.Landmarks\n---\n- launchApp\n- takeScreenshot: Home\n');run('CLI-029','diff',p,[b,'diff','capture','--platform','ios','--simulator',uuid,'--no-build'])
p=s/'046';p.mkdir(exist_ok=True);(p/'grantiva.yml').write_text('scheme: Landmarks\nsimulator: '+uuid+'\nscreens:\n  - name: Diag\n    path:\n      - launch\n      - tap: Open\n      - tap: {text: X, exact: true}\n      - swipe: up\n      - swipe: down\n      - swipe: left\n      - swipe: right\n      - swipe: UP\n      - type: text\n      - wait: 0\n      - assert_visible: Open\n      - assert_not_visible: Missing\n      - assert_not_visible: {text: Missing, exact: true}\n      - run_flow: sub.yaml\n');(p/'sub.yaml').write_text('- tap: Close\n');run('CLI-046','diff',p,[b,'diff','capture','--platform','ios','--simulator',uuid,'--no-build'])
