from pathlib import Path
import subprocess
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli'); ev=root/'findings/evidence/cov5-cli'; cap=ev/'capture-one.rb'; client=ev/'mcp-devicefree-client.py'; s=Path((ev/'scratch-root.txt').read_text().strip())/'batch6'
def run(row,label,cwd,args):
 d=ev/row; d.mkdir(exist_ok=False)
 return subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--','python3',str(client),str(d/(label+'.transcript.json')),str(cwd),*args],cwd=root).returncode
print('099',run('CLI-099-run-2','mcp',s/'099',['--platform','ios','--call-session-tool']))
# direct ambiguous command retains exact nonzero plus fresh explicit-ios protocol success
p=s/'100'; d=ev/'CLI-100-run-2'; d.mkdir(exist_ok=False)
q=subprocess.run(['ruby',str(cap),str(d),'ambiguous',str(p),'--timeout','120','--','/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir',str(p)],cwd=root); print('100amb',q.returncode)
q=subprocess.run(['ruby',str(cap),str(d),'ios',str(p),'--timeout','120','--','python3',str(client),str(d/'ios.transcript.json'),str(p),'--platform','ios'],cwd=root); print('100ios',q.returncode)
