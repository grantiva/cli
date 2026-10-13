#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt37"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt37-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt37'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
rm -f "$SCRATCH/grantiva.yml"
cp "$SCRATCH/.maestro/01-browse.yaml" "$ROOT/01-browse.yaml"
cp "$SCRATCH/.maestro/coverage/11-launch-environment.yaml" "$ROOT/11-launch-environment.yaml"
cp "$SCRATCH/.maestro/coverage/12-env-precedence-cli.yaml" "$ROOT/12-env-precedence-cli.yaml"
cd "$SCRATCH"
runone() { local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"; "$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err"; print -r -- "$?" > "$ROOT/$n.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"
runone appid-header "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --json
runone env-step-wins "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/11-launch-environment.yaml --json
runone env-cli-wins "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/12-env-precedence-cli.yaml --env LANDMARKS_NOTE=from-cli --json
python3 -I - "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1" <<'PY'
import json,os,signal,subprocess,sys,time
root,cwd,g,u=sys.argv[1:]
ready=root+'/readme.ready'
cmd=[g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--logs','--ready-file',ready]
open(root+'/readme-agent.command.json','w').write(json.dumps(cmd)+'\n')
with open(root+'/readme-agent.out','w') as out, open(root+'/readme-agent.err','w') as err:
 p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
 for poll in range(150):
  if os.path.exists(ready) or p.poll() is not None: break
  time.sleep(.2)
 open(root+'/ready-loop.json','w').write(json.dumps({'polls':poll+1,'ready':os.path.exists(ready),'alive':p.poll() is None})+'\n')
 if os.path.exists(ready):
  open(root+'/ready-status.txt','w').write(json.load(open(ready))['status']+'\n')
 for name,args in [('state-xml',[]),('state-format-json',['--format','json']),('state-json-alias',['--json'])]:
  r=subprocess.run([g,'hierarchy','--udid',u,*args],cwd=cwd,capture_output=True,text=True)
  open(root+'/'+name+'.out','w').write(r.stdout); open(root+'/'+name+'.err','w').write(r.stderr); open(root+'/'+name+'.exit.txt','w').write(str(r.returncode)+'\n')
 if p.poll() is None: os.killpg(p.pid,signal.SIGINT)
 try: rc=p.wait(timeout=30)
 except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGTERM); rc=p.wait(timeout=5)
 open(root+'/readme-agent.exit.txt','w').write(str(rc)+'\n')
PY
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
