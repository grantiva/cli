from pathlib import Path
import subprocess,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli');ev=root/'findings/evidence/cov6-cli';cap=ev/'capture-one.rb';client=ev/'mcp-call-client.py';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5');scratch=Path((ev/'scratch-root.txt').read_text().strip())/'batch7';scratch.mkdir(exist_ok=True);empty=scratch/'empty';empty.mkdir(exist_ok=True);cfg=scratch/'config';cfg.mkdir(exist_ok=True);(cfg/'grantiva.yml').write_text('scheme: Landmarks\nscreens: []\n');(cfg/'grantiva-android.yml').write_text('module: app\nscreens: []\n')
def run(row,label,cwd,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root);print(row,label,q.returncode)
# docs rows
run('CLI-161','inspect',src,['/bin/bash','-c','sed -n "88,105p" README.md; find /private/tmp/grantiva-candidate5-coverage-qjr26z3g/cli-runner-home/versions -maxdepth 3 -type d | sort | head -30'])
run('CLI-162','inspect',src,['/bin/bash','-c','sed -n "88,105p" README.md; ! grep -n "fixed 300 s timeout" README.md'])
run('CLI-163','inspect',src,['sed','-n','120,150p','README.md'])
run('CLI-164','inspect',src,['/bin/bash','-c','sed -n "1,40p" docs/mcp.md; /Users/kyle/.grantiva-qa/bin/grantiva mcp --help; sed -n "145,165p" docs/android.md'])
def call(row,tool,args,mode):
 cwd=cfg if mode=='cfg' else empty
 for platform in ['ios','android']:
  run(row,platform,cwd,['python3',str(client),str(ev/f'{row}-run-1'/f'{platform}.transcript.json'),str(cwd),platform,tool,json.dumps(args)])
for row,tool,args,mode in [
('MCP-003','grantiva_screenshot',{},'cfg'),('MCP-004','grantiva_screenshot',{},'empty'),('MCP-007','grantiva_tap',{'label':'x'},'cfg'),('MCP-008','grantiva_tap',{'label':'x'},'empty'),('MCP-011','grantiva_swipe',{'direction':'up'},'cfg'),('MCP-012','grantiva_swipe',{'direction':'up'},'empty'),('MCP-015','grantiva_type',{'text':'x'},'cfg'),('MCP-016','grantiva_type',{'text':'x'},'empty'),('MCP-019','grantiva_a11y_tree',{},'cfg'),('MCP-020','grantiva_a11y_tree',{},'empty'),('MCP-023','grantiva_a11y_check',{},'cfg'),('MCP-024','grantiva_a11y_check',{},'empty'),('MCP-027','grantiva_script',{'steps':[]},'cfg'),('MCP-028','grantiva_script',{'steps':[]},'empty'),('MCP-033','grantiva_build',{},'empty'),('MCP-038','grantiva_run',{},'empty'),('MCP-041','grantiva_test',{},'empty'),('MCP-046','grantiva_context',{},'empty'),('MCP-072','grantiva_vrt_compare',{},'empty'),('MCP-075','grantiva_vrt_approve',{},'empty')]:call(row,tool,args,mode)
# 067 missing config, then no-screens config, both platforms
call('MCP-067','grantiva_vrt_capture',{},'empty')
no=scratch/'noscreens';no.mkdir(exist_ok=True);(no/'grantiva.yml').write_text('scheme: Landmarks\nscreens: []\n');(no/'grantiva-android.yml').write_text('module: app\nscreens: []\n')
for platform in ['ios','android']:run('MCP-067',f'{platform}-noscreens',no,['python3',str(client),str(ev/'MCP-067-run-1'/f'{platform}-noscreens.transcript.json'),str(no),platform,'grantiva_vrt_capture','{}'])
