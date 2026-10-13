#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt29"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt29-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt29'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
YAML
cat > "$ROOT/keepalive.py" <<'PY'
import json,os,signal,shutil,subprocess,sys,time
root,scratch,g,u=sys.argv[1:]; ready=root+'/keepalive.ready'
cmd=[g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--ready-file',ready]
open(root+'/keepalive.command.json','w').write(json.dumps(cmd)+'\n')
p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/keepalive.out','w'),stderr=open(root+'/keepalive.err','w'),start_new_session=True)
open(root+'/keepalive.pid','w').write(str(p.pid)+'\n')
for n in range(90):
 if os.path.exists(ready): break
 if p.poll() is not None: break
 time.sleep(1)
open(root+'/ready-observation.json','w').write(json.dumps({'exists':os.path.exists(ready),'polls':n+1,'processAlive':p.poll() is None})+'\n')
if os.path.exists(ready): shutil.copy2(ready,root+'/keepalive.ready-before-signal')
def run(name,args):
 cp=subprocess.run(args,cwd=scratch,capture_output=True,text=True)
 open(root+'/'+name+'.command.json','w').write(json.dumps(args)+'\n'); open(root+'/'+name+'.out','w').write(cp.stdout); open(root+'/'+name+'.err','w').write(cp.stderr); open(root+'/'+name+'.exit.txt','w').write(str(cp.returncode)+'\n')
run('hierarchy-xml',[g,'hierarchy','--udid',u])
run('hierarchy-format-json',[g,'hierarchy','--udid',u,'--format','json'])
run('hierarchy-json-alias',[g,'hierarchy','--udid',u,'--json'])
run('hierarchy-timeout',[g,'hierarchy','--udid',u,'--timeout','0.01'])
run('hierarchy-after-ready',[g,'hierarchy','--udid',u,'--format','json'])
open(root+'/pre-signal-ps.txt','w').write(subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],capture_output=True,text=True).stdout)
if p.poll() is None: os.killpg(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:
 os.killpg(p.pid,signal.SIGTERM)
 try:p.wait(timeout=5)
 except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGKILL); p.wait(timeout=5)
 rc=124
open(root+'/keepalive.exit.txt','w').write(str(rc)+'\n')
if os.path.exists(ready): shutil.copy2(ready,root+'/keepalive.ready-after-signal')
open(root+'/post-signal-ps.txt','w').write(subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],capture_output=True,text=True).stdout)
PY
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/keepalive.py" "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1"; rc=$?
echo "helper_exit=$rc" >> "$ROOT/commands.txt"; echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
