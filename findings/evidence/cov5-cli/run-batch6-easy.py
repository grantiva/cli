from pathlib import Path
import subprocess
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli'); ev=root/'findings/evidence/cov5-cli'; cap=ev/'capture-one.rb'; src=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate4'); cli='/Users/kyle/.grantiva-qa/bin/grantiva'
def run(row,label,cwd,argv):
 d=ev/row; d.mkdir(exist_ok=False); q=subprocess.run(['ruby',str(cap),str(d),label,str(cwd),'--timeout','120','--',*argv],cwd=root); print(row,q.returncode)
run('CLI-113-run-2','inspect',src,['/bin/bash','-c',f"sed -n '348,355p' README.md; {cli} simulator cleanup --help; sed -n '16,24p' /Users/kyle/Developer/grantiva-cli/.worktrees/regression/SIMULATOR-LIFECYCLE.md"])
run('CLI-157-run-1','doctor-pipe',src,['/bin/bash','-o','pipefail','-c',f"{cli} doctor --json | jq '.[] | select(.status == \"fail\")'"])
run('CLI-158-run-1','console-help',src,[cli,'console','--help'])
d=ev/'CLI-158-run-1'; subprocess.run(['ruby',str(cap),str(d),'flags-help',str(src),'--timeout','120','--',cli,'console','flags','--help'],cwd=root)
run('CLI-160-run-1','exports',src,['/bin/bash','-c','export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"; export GRANTIVA_RUNNER_HOME="/private/tmp/grantiva-cov5-cli-gtwQZB/runner-home"; printf "%s\\n%s\\n%s\\n" "$ANDROID_HOME" "$PATH" "$GRANTIVA_RUNNER_HOME"'])
# exact MCP documentation/live set assertion
script=ev/'cli122-compare.py'; script.write_text('''import json,re,sys\nfrom pathlib import Path\ndoc=Path(sys.argv[1]).read_text()\nrows=re.findall(r"^\\| `(grantiva_[^`]+)` \\| ([^|]+) \\|",doc,re.M)\nactual=json.loads(Path(sys.argv[2]).read_text())[1]["result"]["tools"]\nnames={x["name"] for x in actual}; expected={n for n,_ in rows}\nprint(json.dumps({"documented_count":len(expected),"live_count":len(names),"missing":sorted(expected-names),"extra":sorted(names-expected),"ios_only_test":dict(rows).get("grantiva_test"),"android_only_emulators":{n:p.strip() for n,p in rows if n.startswith("grantiva_emulator_")}},indent=2))\nassert expected==names and len(names)==22\nassert dict(rows)["grantiva_test"].strip()=="iOS only"\nassert all(p.strip()=="Android only" for n,p in rows if n.startswith("grantiva_emulator_"))\n''')
run('CLI-122-run-2','compare',root,['python3',str(script),str(src/'docs/mcp.md'),str(ev/'CLI-122-run-1/tools-list.transcript.json')])
