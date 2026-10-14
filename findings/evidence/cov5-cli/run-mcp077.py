from pathlib import Path
import subprocess,json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';client=ev/'mcp-call-client.py';empty=Path((ev/'scratch-root.txt').read_text().strip())/'batch7/empty';d=ev/'MCP-077-run-1';d.mkdir(exist_ok=False)
for label,platform,tool,args in [('unknown','ios','no_such_tool',{}),('sim-ensure','ios','grantiva_sim_ensure',{}),('type','ios','grantiva_type',{}),('swipe','ios','grantiva_swipe',{}),('script','ios','grantiva_script',{}),('emulator-ensure','android','grantiva_emulator_ensure',{})]:
 q=subprocess.run(['ruby',str(cap),str(d),label,str(empty),'--timeout','120','--','python3',str(client),str(d/f'{label}.transcript.json'),str(empty),platform,tool,json.dumps(args)],cwd=root);print(label,q.returncode)
