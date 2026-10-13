#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt30"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt30-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt30'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
YAML
cd "$SCRATCH"
runone() { local name=$1; shift; print -r -- "$*" > "$ROOT/$name.command.txt"; "$@" > "$ROOT/$name.out" 2> "$ROOT/$name.err"; print -r -- "$?" > "$ROOT/$name.exit.txt"; ps -axo pid=,ppid=,pgid=,state=,etime=,command= > "$ROOT/$name.post-ps.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
runone logs-default "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/08-caching.yaml --logs
runone logs-predicate "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/08-caching.yaml --logs-predicate 'subsystem == "com.kylebrowning.Landmarks"'
runone logs-debug "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/08-caching.yaml --logs --logs-level debug
runone logs-info "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/08-caching.yaml --logs --logs-level info
runone logs-level-default "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/08-caching.yaml --logs --logs-level default
runone logs-failure "$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/99-crash.yaml --logs
cat > "$ROOT/interrupt.py" <<'PY'
import json,os,signal,subprocess,sys,time
root,scratch,g,u,home=sys.argv[1:]
ready=root+'/interrupt.ready'; cmd=[g,'run','--no-build','--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--logs','--ready-file',ready]
def snapshot(stage):
 lock=home+'/locks/'+u+'.lock'
 open(root+'/'+stage+'-lock-path.txt','w').write(lock+'\nexists='+str(os.path.exists(lock))+'\n')
 if os.path.exists(lock): open(root+'/'+stage+'-lock-content.txt','wb').write(open(lock,'rb').read())
 sessions='/tmp/grantiva-sessions'; matches=[]
 if os.path.isdir(sessions):
  for name in os.listdir(sessions):
   path=os.path.join(sessions,name)
   if os.path.isfile(path):
    try: data=open(path,'rb').read()
    except OSError: continue
    if u.encode() in data: matches.append((path,data))
 open(root+'/'+stage+'-matching-global-sessions.txt','w').write('\n'.join(x[0] for x in matches)+'\n')
 for i,(path,data) in enumerate(matches): open(root+'/'+stage+f'-global-session-{i}.bin','wb').write(data)
snapshot('before')
open(root+'/interrupt.command.json','w').write(json.dumps(cmd)+'\n')
p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/interrupt.out','w'),stderr=open(root+'/interrupt.err','w'),start_new_session=True)
open(root+'/interrupt.pid','w').write(str(p.pid)+'\n')
rows=[]
for n in range(20):
 time.sleep(1)
 if p.poll() is not None: break
 ps=subprocess.run(['ps','-axo','pid=,ppid=,pgid=,state=,etime=,command='],capture_output=True,text=True).stdout
 rows=[x for x in ps.splitlines() if len(x.split())>=3 and x.split()[2].isdigit() and int(x.split()[2])==p.pid]
 if os.path.exists(ready) and any('log stream' in x for x in rows): break
open(root+'/during-process-group.txt','w').write('\n'.join(rows)+'\n'); snapshot('during')
for label,path in [('project',scratch+'/.grantiva')]:
 cp=subprocess.run(['find',path,'-maxdepth','4','-type','f','-print'],capture_output=True,text=True)
 open(root+'/during-'+label+'-files.txt','w').write(cp.stdout)
open(root+'/signal.json','w').write(json.dumps({'pid':p.pid,'elapsed':n+1,'sawLogStream':any('log stream' in x for x in rows)})+'\n')
if p.poll() is None: os.killpg(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:
 os.killpg(p.pid,signal.SIGTERM); p.wait(timeout=5); rc=124
open(root+'/interrupt.exit.txt','w').write(str(rc)+'\n')
ps2=subprocess.run(['ps','-axo','pid=,ppid=,pgid=,state=,etime=,command='],capture_output=True,text=True).stdout
open(root+'/after-original-group.txt','w').write('\n'.join(x for x in ps2.splitlines() if len(x.split())>=3 and x.split()[2].isdigit() and int(x.split()[2])==p.pid)+'\n'); snapshot('after')
for label,path in [('project',scratch+'/.grantiva')]:
 cp=subprocess.run(['find',path,'-maxdepth','4','-type','f','-print'],capture_output=True,text=True)
 open(root+'/after-'+label+'-files.txt','w').write(cp.stdout)
PY
python3 -I "$ROOT/interrupt.py" "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1" "$GRANTIVA_RUNNER_HOME"; interrupt_helper_rc=$?
{
 echo "logs_default=$(cat "$ROOT/logs-default.exit.txt")"; echo "logs_predicate=$(cat "$ROOT/logs-predicate.exit.txt")"; echo "logs_debug=$(cat "$ROOT/logs-debug.exit.txt")"; echo "logs_info=$(cat "$ROOT/logs-info.exit.txt")"; echo "logs_level_default=$(cat "$ROOT/logs-level-default.exit.txt")"; echo "logs_failure=$(cat "$ROOT/logs-failure.exit.txt")"; echo "interrupt_helper=$interrupt_helper_rc"; echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
