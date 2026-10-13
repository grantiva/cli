#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt27"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt27-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt27'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
cat > "$ROOT/interrupt.py" <<'PY'
import json,os,signal,subprocess,sys,time
root,scratch,grantiva,udid=sys.argv[1:]
cmd=[grantiva,'run','--no-build','--simulator',udid,'--flow','.maestro/coverage/18-long-wait.yaml','--ready-file',root+'/interrupted.ready','--report-dir',root+'/interrupted-report']
open(root+'/interrupt.command.json','w').write(json.dumps(cmd)+'\n')
t0=time.monotonic(); p=subprocess.Popen(cmd,cwd=scratch,stdout=open(root+'/interrupt.out','w'),stderr=open(root+'/interrupt.err','w'),start_new_session=True)
open(root+'/interrupt.pid','w').write(str(p.pid)+'\n')
# Allow the owned flow to enter its long wait, preserving snapshots before signalling only this process group.
for i in range(12):
 time.sleep(1)
 subprocess.run(['ps','-axo','pid=,ppid=,state=,etime=,command='],stdout=open(root+f'/interrupt-ps-{i+1:02d}.txt','w'))
 if p.poll() is not None: break
if p.poll() is None:
 open(root+'/signal-timing.json','w').write(json.dumps({'signal':'SIGINT','elapsedSeconds':time.monotonic()-t0,'pid':p.pid})+'\n')
 os.killpg(p.pid,signal.SIGINT)
try: rc=p.wait(timeout=30)
except subprocess.TimeoutExpired:
 open(root+'/harness-timeout.txt','w').write('owned process group did not exit within 30s after SIGINT; terminating only that recorded group\n')
 os.killpg(p.pid,signal.SIGTERM)
 try: p.wait(timeout=5)
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGKILL); p.wait(timeout=5)
 rc=124
open(root+'/interrupt.exit.txt','w').write(str(rc)+'\n')
open(root+'/interrupt.elapsed-seconds.txt','w').write(str(time.monotonic()-t0)+'\n')
PY
cat > "$SCRATCH/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
YAML
cd "$SCRATCH"
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "owned_device_udid=$U1"; echo "scratch=$SCRATCH"
} > "$ROOT/commands.txt"
python3 -I "$ROOT/interrupt.py" "$ROOT" "$SCRATCH" "$GRANTIVA" "$U1"; interrupt_harness_rc=$?
"$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/coverage/18-long-wait.yaml --timeout 3 --ready-file "$ROOT/timeout.ready" --report-dir "$ROOT/timeout-report" > "$ROOT/timeout.out" 2> "$ROOT/timeout.err"; timeout_rc=$?
"$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --ready-file "$ROOT/pass-ephemeral.ready" > "$ROOT/pass-ephemeral.out" 2> "$ROOT/pass-ephemeral.err"; pass_ephemeral_rc=$?
"$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --ready-file "$ROOT/pass-report.ready" --report-dir "$ROOT/pass-report" > "$ROOT/pass-report.out" 2> "$ROOT/pass-report.err"; pass_report_rc=$?
{
 echo "interrupt_harness_exit=$interrupt_harness_rc"; echo "timeout_exit=$timeout_rc"; echo "pass_ephemeral_exit=$pass_ephemeral_rc"; echo "pass_report_exit=$pass_report_rc"; echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
