from pathlib import Path
import json, subprocess
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli'); ev=root/'findings/evidence/cov5-cli'; cap=ev/'capture-one.rb'; src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4'); cli='/Users/kyle/.grantiva-qa/bin/grantiva'; base=Path((ev/'scratch-root.txt').read_text().strip())/'batch13'; base.mkdir(exist_ok=True)
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1'; d.mkdir(exist_ok=True); p=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root); print(row,label,p.returncode)
run('B-R03.1','readme-fixed-timeout',src,['rg','-n','fixed 300 s timeout|fixed 300|300 s timeout','README.md'])
run('B-R03.1','readme-timeout-section',src,['sed','-n','90,105p','README.md'])
run('B-R03.3','readme-options',src,['sed','-n','90,105p','README.md'])
run('B-R03.3','run-help',src,[cli,'run','--help'])
empty=base/'empty'; empty.mkdir()
for tool,args in [('grantiva_build',{}),('grantiva_vrt_capture',{}),('grantiva_run',{}),('grantiva_test',{})]:
 out=ev/'B-R04.1-run-1' if tool in ('grantiva_build','grantiva_vrt_capture') else ev/'B-R04.2-run-1'; out.mkdir(exist_ok=True)
 run('B-R04.1' if tool in ('grantiva_build','grantiva_vrt_capture') else 'B-R04.2',tool,root,['python3',str(ev/'mcp-call-client.py'),str(out/f'{tool}.json'),str(empty),'ios',tool,json.dumps(args)])
cfg=base/'no-screens'; cfg.mkdir(); (cfg/'grantiva.yml').write_text('scheme: Landmarks\nbundle_id: com.example.app\nflows: []\n')
run('B-R04.3','vrt-no-screens',root,['python3',str(ev/'mcp-call-client.py'),str(ev/'B-R04.3-run-1/result.json'),str(cfg),'ios','grantiva_vrt_capture','{}'])
run('B-R04.4','source-test',src,['rg','-n','grantiva_build|No grantiva.yml|not found|missing.*config','Tests/GrantivaMCPTests'])
run('B-R05.4','source-test',src,['rg','-n','session.*starting|starting.*session|no sessionId|ToolRegistry.call','Tests/GrantivaMCPTests'])
run('N-07','runner-start-help',src,[cli,'runner','start','--help'])
