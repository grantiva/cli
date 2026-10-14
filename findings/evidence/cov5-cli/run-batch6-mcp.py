from pathlib import Path
import subprocess,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';s=Path((ev/'scratch-root.txt').read_text().strip())/'batch6';s.mkdir(exist_ok=True);client=ev/'mcp-devicefree-client.py'
def run(row,label,cwd,args):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--','python3',str(client),str(d/(label+'.transcript.json')),str(cwd),*args],cwd=root);return {'row':row,'label':label,'exit':q.returncode}
r=[];empty=s/'empty';empty.mkdir(exist_ok=True);r.append(run('CLI-097','mcp',empty,[]))
# nonexistent startup is a direct command, not the protocol client
d=ev/'CLI-098-run-1';d.mkdir();q=subprocess.run(['ruby',str(cap),str(d),'mcp',str(root),'--timeout','120','--','/Users/kyle/.grantiva-qa/bin/grantiva','mcp','--project-dir','/nonexistent'],cwd=root);r.append({'row':'CLI-098','label':'mcp','exit':q.returncode})
p=s/'099';p.mkdir(exist_ok=True);(p/'grantiva.yml').write_text('scheme: Landmarks\nsimulator: 00000000-0000-0000-0000-000000000527\nscreens: []\n');r.append(run('CLI-099','mcp',p,['--platform','ios','--call-session-tool']))
p=s/'100';p.mkdir(exist_ok=True);(p/'grantiva.yml').write_text('screens: []\n');(p/'grantiva-android.yml').write_text('screens: []\n');r.append(run('CLI-100','ambiguous',p,[]));r.append(run('CLI-100','ios',p,['--platform','ios']))
r.append(run('CLI-122','tools-list',empty,[]))
(ev/'batch6-mcp-execution.json').write_text(json.dumps(r,indent=2)+'\n')
