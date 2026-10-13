#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt70"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt70-ios"; U1=563907E1-703D-4322-AE5F-FC3B06D03143
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt70'; exit 73; fi
mkdir -p "$ROOT";cp "$0" "$ROOT/harness.sh";rsync -a --exclude '.grantiva' "$SRC/" "$A/"
cat > "$ROOT/client.py" <<'PY'
import json,os,signal,subprocess,sys,time
from pathlib import Path
root,cwd,grantiva,udid=sys.argv[1:]
root=Path(root); cwd=Path(cwd)
cases=[('plain',[]),('quiet',['--quiet']),('json',['--json'])]
summary=[]
for name,mode in cases:
    session=cwd/'.grantiva/session.json'
    if session.exists(): raise SystemExit(f'{name}: pre-existing session')
    argv=[grantiva,'runner','start','--bundle-id','com.kylebrowning.Landmarks','--simulator',udid,'--platform','ios',*mode]
    (root/f'{name}.command.json').write_text(json.dumps(argv,indent=2))
    out=open(root/f'{name}.out','wb'); err=open(root/f'{name}.err','wb')
    p=subprocess.Popen(argv,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
    (root/f'{name}.pid').write_text(str(p.pid)+'\n')
    observed=[]; deadline=time.monotonic()+30
    while time.monotonic()<deadline and p.poll() is None:
        if session.exists():
            try:
                raw=session.read_text(); doc=json.loads(raw); observed.append(doc)
                (root/f'{name}.session-before-signal.json').write_text(json.dumps(doc,indent=2,sort_keys=True))
                break
            except Exception as e:(root/f'{name}.session-read-error.txt').write_text(repr(e))
        time.sleep(.05)
    if not observed:
        os.killpg(p.pid,signal.SIGINT); p.wait(timeout=30); out.close(); err.close(); raise SystemExit(f'{name}: no session before signal')
    sent=time.time(); os.killpg(p.pid,signal.SIGINT)
    try: rc=p.wait(timeout=30)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid,signal.SIGKILL);rc=p.wait();(root/f'{name}.forced-kill').write_text('true\n')
    out.close();err.close()
    (root/f'{name}.exit.txt').write_text(str(rc)+'\n')
    (root/f'{name}.timing.json').write_text(json.dumps({'signalEpoch':sent,'exitEpoch':time.time()},indent=2))
    for _ in range(100):
        if not session.exists():break
        time.sleep(.05)
    (root/f'{name}.session-after.txt').write_text('present\n' if session.exists() else 'absent\n')
    subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],stdout=open(root/f'{name}.ps-after.txt','wb'),stderr=subprocess.DEVNULL)
    summary.append({'name':name,'exit':rc,'sessionState':observed[-1].get('state'),'sessionAfter':session.exists()})
(root/'summary.json').write_text(json.dumps(summary,indent=2))
if any(x['exit']!=130 or x['sessionAfter'] for x in summary): raise SystemExit(1)
PY
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)";shasum -a 256 "$GRANTIVA" "$ROOT/client.py";echo "owned_device_udid=$U1"
 echo 'B3-L37 foreground runner start plain/quiet/JSON; each signalled by exact recorded process group after session publication.'
} > "$ROOT/commands.txt"
xcrun simctl list devices -j > "$ROOT/simulators-before.json"
python3 -I "$ROOT/client.py" "$ROOT" "$A" "$GRANTIVA" "$U1" > "$ROOT/client.out" 2> "$ROOT/client.err";print -r -- "$?" > "$ROOT/client.exit.txt"
xcrun simctl list devices -j > "$ROOT/simulators-after.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
[[ $(<"$ROOT/client.exit.txt") == 0 ]]
