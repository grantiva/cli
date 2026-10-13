#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt33"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt33-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
APP="$BASE/attempt26-ios/flag-derived-data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt33'; exit 73; fi
[[ -d "$APP" ]] || { print -u2 'missing proven simulator app artifact'; exit 74; }
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
bundle_id: com.kylebrowning.Landmarks
YAML
cat > "$ROOT/case.py" <<'PY'
import json,os,signal,subprocess,sys,time
root,scratch,g,u,name,flow,*envs=sys.argv[1:]
ready=root+'/'+name+'.ready'; cmd=[g,'run','--no-build','--simulator',u,'--flow',flow,'--keep-alive','--ready-file',ready]
for e in envs:cmd+=['--env',e]
open(root+'/'+name+'.command.json','w').write(json.dumps(cmd)+'\n')
p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/'+name+'.out','w'),stderr=open(root+'/'+name+'.err','w'),start_new_session=True)
for n in range(90):
 if os.path.exists(ready) or p.poll() is not None:break
 time.sleep(1)
open(root+'/'+name+'.observation.json','w').write(json.dumps({'ready':os.path.exists(ready),'alive':p.poll() is None,'polls':n+1})+'\n')
cp=subprocess.run([g,'hierarchy','--udid',u,'--format','json'],cwd=scratch,capture_output=True,text=True)
open(root+'/'+name+'.hierarchy.json','w').write(cp.stdout); open(root+'/'+name+'.hierarchy.err','w').write(cp.stderr); open(root+'/'+name+'.hierarchy.exit.txt','w').write(str(cp.returncode)+'\n')
if p.poll() is None:os.killpg(p.pid,signal.SIGINT)
try:rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=5);rc=124
open(root+'/'+name+'.exit.txt','w').write(str(rc)+'\n')
PY
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "app_file=$APP"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/case.py" "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1" env-equals .maestro/coverage/22-show-note.yaml 'LANDMARKS_NOTE=a=b c'
python3 -I "$ROOT/case.py" "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1" env-hello .maestro/coverage/22-show-note.yaml LANDMARKS_NOTE=hello
python3 -I "$ROOT/case.py" "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1" env-repeatable .maestro/coverage/08-scroll.yaml LANDMARKS_SEED=many LANDMARKS_NOTE=x
cd "$SCRATCH"
"$GRANTIVA" run --app-file "$APP" --simulator "$U1" --flow .maestro/01-browse.yaml --json > "$ROOT/app-file.out" 2> "$ROOT/app-file.err"; echo $? > "$ROOT/app-file.exit.txt"
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
