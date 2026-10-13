#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios-a74
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt74"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; A="$BASE/attempt74-ios"; NAME='cov3-ios-74-killed iPhone 17'
APP="$BASE/attempt44-ios/round3 derived data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
if [[ -e "$ROOT" || -e "$A" ]]; then print -u2 'refusing overwrite attempt74'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$A/"
xcrun simctl list devices -j > "$ROOT/before.json"
python3 - "$ROOT/before.json" "$NAME" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); assert not any(x.get('name')==sys.argv[2] for xs in d['devices'].values() for x in xs)
PY
U=''
cleanup() {
  [[ -n "$U" ]] || return
  xcrun simctl list devices -j > "$ROOT/cleanup-before.json" 2> "$ROOT/cleanup-before.err" || return
  python3 - "$ROOT/cleanup-before.json" "$NAME" "$U" <<'PY' || return
import json,sys
d=json.load(open(sys.argv[1])); hits=[x for xs in d['devices'].values() for x in xs if x.get('name')==sys.argv[2] and x.get('udid')==sys.argv[3]]
raise SystemExit(0 if len(hits)==1 else 1)
PY
  "$GRANTIVA" simulator teardown --udid "$U" --force --json > "$ROOT/cleanup-teardown.out" 2> "$ROOT/cleanup-teardown.err" || true
  xcrun simctl delete "$U" > "$ROOT/cleanup.out" 2> "$ROOT/cleanup.err" || true
  xcrun simctl list devices -j > "$ROOT/cleanup-after.json" 2> "$ROOT/cleanup-after.err" || true
}
trap cleanup EXIT
U=$(xcrun simctl create "$NAME" 'iPhone 17' 'iOS 26.0') || exit 75
python3 - "$U" <<'PY' || exit 76
import re,sys
assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',sys.argv[1])
PY
print -r -- "$U" > "$ROOT/owned.udid"
cd "$A"
cat > "$ROOT/kill-helper.py" <<'PY'
import json,os,signal,subprocess,sys,time
root,cwd,g,u,app,home=sys.argv[1:]; report=root+'/preserved-report'; lock=home+'/locks/'+u+'.lock'
cmd=[g,'run','--app-file',app,'--simulator',u,'--flow','.maestro/01-browse.yaml','--keep-alive','--ready-file',root+'/ready.json','--report-dir',report]
open(root+'/run.command.json','w').write(json.dumps(cmd,indent=2)+'\n')
out=open(root+'/run.out','wb');err=open(root+'/run.err','wb');p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
open(root+'/run.pid','w').write(str(p.pid)+'\n')
deadline=time.monotonic()+90
while time.monotonic()<deadline and p.poll() is None:
    if os.path.exists(root+'/ready.json'):
        try:
            if json.load(open(root+'/ready.json')).get('status')=='passed': break
        except Exception: pass
    time.sleep(.1)
else: raise SystemExit('run never reached passed keep-alive hold')
if not os.path.exists(lock): raise SystemExit('lease claim absent')
open(root+'/lock-before-kill.bin','wb').write(open(lock,'rb').read())
subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],stdout=open(root+'/ps-before-kill.txt','wb'))
os.kill(p.pid,signal.SIGKILL); rc=p.wait(timeout=15); out.close();err.close()
open(root+'/run.exit.txt','w').write(str(rc)+'\n')
time.sleep(2)
subprocess.run(['ps','-axo','pid,ppid,pgid,etime,command'],stdout=open(root+'/ps-after-kill.txt','wb'))
PY
python3 -I "$ROOT/kill-helper.py" "$ROOT" "$A" "$GRANTIVA" "$U" "$APP" "$GRANTIVA_RUNNER_HOME" > "$ROOT/helper.out" 2> "$ROOT/helper.err"; print -r -- "$?" > "$ROOT/helper.exit.txt"
[[ $(<"$ROOT/helper.exit.txt") == 0 ]] || exit 77
find "$GRANTIVA_RUNNER_HOME/versions" -path "*/devices/$U" -type d -print > "$ROOT/homes-before-teardown.txt"
"$GRANTIVA" simulator teardown --udid "$U" --force --json > "$ROOT/teardown.out" 2> "$ROOT/teardown.err"; print -r -- "$?" > "$ROOT/teardown.exit.txt"
find "$GRANTIVA_RUNNER_HOME/versions" -path "*/devices/$U" -type d -print > "$ROOT/homes-after-teardown.txt"
[[ -d "$ROOT/preserved-report" ]] && print present > "$ROOT/preserved-report-after.txt" || print absent > "$ROOT/preserved-report-after.txt"
[[ -e .grantiva/session.json ]] && print present > "$ROOT/session-after.txt" || print absent > "$ROOT/session-after.txt"
ps -axo pid,ppid,pgid,etime,command > "$ROOT/ps-after-teardown.txt"
xcrun simctl list devices -j > "$ROOT/final.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ROOT/completed.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files-before-exit.sha256"
[[ $(<"$ROOT/teardown.exit.txt") == 0 && $(<"$ROOT/preserved-report-after.txt") == present && $(<"$ROOT/session-after.txt") == absent ]]
