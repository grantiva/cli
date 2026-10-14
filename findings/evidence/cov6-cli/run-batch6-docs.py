from pathlib import Path
import subprocess
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli'); ev=root/'findings/evidence/cov6-cli'; cap=ev/'capture-one.rb'; src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5'); cli='/Users/kyle/.grantiva-qa/bin/grantiva'
def run(row, script):
 d=ev/f'{row}-run-1'; d.mkdir(exist_ok=False)
 q=subprocess.run(['ruby',str(cap),str(d),'inspect',str(src),'--timeout','120','--','/bin/bash','-c',script],cwd=root)
 print(row,q.returncode)
run('CLI-110',f"sed -n '365,369p' README.md; for x in install start status stop; do {cli} runner $x --help; done")
run('CLI-111',f"sed -n '305,338p' README.md; {cli} --help; for x in run build record hierarchy doctor init mcp; do {cli} $x --help; done")
run('CLI-112',"sed -n '158,174p' README.md; cat '/Users/kyle/Developer/grantiva-cli/.worktrees/cov6-cli/findings/evidence/cov6-cli/CLI-065-run-1/unsupported.stderr'")
run('CLI-113',f"sed -n '315,324p' README.md; {cli} simulator cleanup --help; cat docs/SIMULATOR-LIFECYCLE.md")
run('CLI-114',f"sed -n '315,321p' README.md; {cli} simulator --help; {cli} simulator delete --help; {cli} simulator sessions --help")
run('CLI-117',"sed -n '20,24p' docs/android-environment.md; sed -n '71,73p' docs/android.md")
run('CLI-118',"sed -n '30,40p' docs/android.md")
run('CLI-119',f"sed -n '1,5p' README.md; {cli} --help; {cli} run --help; {cli} build build --help; {cli} record --help; {cli} hierarchy --help")
run('CLI-120',f"sed -n '365,369p' README.md; sed -n '34,42p' docs/dump-hierarchy.md; {cli} hierarchy --help")
run('CLI-121',f"sed -n '82,90p' README.md; {cli} run --help")
