from pathlib import Path
import subprocess
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli';cap=ev/'capture-one.rb';src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4');cli='/Users/kyle/.grantiva-qa/bin/grantiva'
def run(row,label,argv):
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);q=subprocess.run(['ruby',str(cap),str(d),label,str(src),'--timeout','120','--',*argv],cwd=root);print(row,q.returncode)
queries={'B-C25.2':'AuthStore|func delete|removed','B-C25.3':'AuthCommandTests|No stored credentials|Not logged in','B-D01.3':'HierarchyCommandTests|DumpHierarchyCommandTests|format.*json','B-D02.3':'SimulatorCommandTests|non-empty abstract|capacity slots','B-D04.3':'abstract.*simulator|emulator.*abstract','B-D07.2':'configured AVD|only AVD|booting emulator','B-D08.2':'ReadyFileTests|parent director','B-D09.2':'ToolRegistrationTests|documented.*registered|tool names','B-I01.3':'derived.data|different UDID|devices/'}
for row,q in queries.items():run(row,'source-inspection',['rg','-n','-i',q,'Sources','Tests'])
docs={
'B-C26.1':"sed -n '80,105p' README.md",'B-C26.2':f"{cli} run --help",'B-C26.3':"sed -n '80,105p' README.md",'B-D01.2':"sed -n '360,372p' README.md; sed -n '34,55p' docs/dump-hierarchy.md",'B-D02.1':"sed -n '337,370p' README.md",'B-D02.2':f"sed -n '348,355p' README.md; {cli} simulator cleanup --help",'B-D03.1':"sed -n '588,598p' README.md",'B-D04.1':f"{cli} --help; {cli} run --help; {cli} build build --help",'B-D04.2':"sed -n '1,6p' README.md",'B-D05.1':f"{cli} --version; test ! -e CHANGELOG.md; rg -n '2\\.1\\.0|version' Package.swift README.md docs | head -100",'B-D06.1':"sed -n '18,30p' docs/android-environment.md",'B-D07.1':"sed -n '30,42p' docs/android.md",'B-D08.1':f"sed -n '82,100p' README.md; {cli} run --help",'B-D09.1':"sed -n '1,220p' docs/mcp.md"}
for row,s in docs.items():run(row,'inspect',['/bin/bash','-c',s])
