#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios-a129
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt129"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
APP=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt44-ios/round3\ derived\ data/Build/Products/UITesting-iphonesimulator/Landmarks.app
A=/private/tmp/cov3-ios-attempt129
NAME='cov3-ios-129-killed-nonkeepalive'
[[ ! -e "$ROOT" && ! -e "$A" && -d "$APP" ]] || exit 73
mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A/"; cp "$0" "$ROOT/harness.sh"
xcrun simctl list devices -j >"$ROOT/before.json"
python3 - "$ROOT/before.json" "$NAME" <<'PY' || exit 74
import json,sys
d=json.load(open(sys.argv[1])); assert not any(x.get('name')==sys.argv[2] for a in d['devices'].values() for x in a)
PY
U=''
cleanup(){
 [[ -n "$U" ]] || return
 "$GRANTIVA" simulator teardown --udid "$U" --force --json >>"$ROOT/cleanup-teardown.out" 2>>"$ROOT/cleanup-teardown.err" || true
 xcrun simctl delete "$U" >>"$ROOT/cleanup-delete.out" 2>>"$ROOT/cleanup-delete.err" || true
 xcrun simctl list devices -j >"$ROOT/cleanup-after.json" 2>/dev/null || true
}
trap cleanup EXIT
U=$(xcrun simctl create "$NAME" 'iPhone 17' 'iOS 26.0') || exit 75
python3 - "$U" <<'PY' || exit 76
import re,sys
assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',sys.argv[1])
PY
print -r -- "$U" >"$ROOT/owned.udid"
cat >"$ROOT/helper.py" <<'PY'
import json,os,signal,subprocess,sys,time
r,cwd,g,u,app,home=sys.argv[1:]
cmd=[g,'run','--app-file',app,'--simulator',u,'--flow','.maestro/11-slow.yaml']
open(r+'/run.command.json','w').write(json.dumps(cmd,indent=2)+'\n')
out=open(r+'/run.out','wb'); err=open(r+'/run.err','wb')
p=subprocess.Popen(cmd,cwd=cwd,stdout=out,stderr=err,start_new_session=True)
open(r+'/run.pid','w').write(str(p.pid)+'\n')
lock=home+'/locks/'+u+'.lock'; deadline=time.monotonic()+30
while time.monotonic()<deadline and p.poll() is None:
 if os.path.exists(lock):
  try:
   claim=json.load(open(lock))
   if claim.get('pid')==p.pid and len(claim.get('temporaryDirectories',[]))>=2: break
  except Exception: pass
 time.sleep(.05)
else: raise SystemExit('owned claim with two temp dirs not observed while run alive')
open(r+'/claim-before-kill.json','w').write(json.dumps(claim,indent=2)+'\n')
for x in claim['temporaryDirectories']:
 if not os.path.exists(x): raise SystemExit('claimed temp missing '+x)
os.kill(p.pid,signal.SIGKILL); rc=p.wait(timeout=15); out.close(); err.close()
open(r+'/run.exit','w').write(str(rc)+'\n')
PY
{
 date -u +started_utc=%Y-%m-%dT%H:%M:%SZ
 shasum -a 256 "$GRANTIVA"
 print -r -- "owned_name=$NAME"
} >"$ROOT/commands.txt"
python3 -I "$ROOT/helper.py" "$ROOT" "$A" "$GRANTIVA" "$U" "$APP" "$GRANTIVA_RUNNER_HOME" >"$ROOT/helper.out" 2>"$ROOT/helper.err" || exit 77
"$GRANTIVA" simulator teardown --udid "$U" --force --json >"$ROOT/teardown.out" 2>"$ROOT/teardown.err"; print -r -- $? >"$ROOT/teardown.exit"
python3 - "$ROOT" <<'PY' || exit 78
import json,os,pathlib,sys
r=pathlib.Path(sys.argv[1]); claim=json.load(open(r/'claim-before-kill.json')); out=json.load(open(r/'teardown.out'))
row=out[0] if isinstance(out,list) else out
claimed=sorted(claim['temporaryDirectories']); removed=sorted(row.get('temporaryDirectoriesRemoved',[]))
assert len(claimed)>=2,(claimed,row)
assert all(x in removed for x in claimed),(claimed,removed)
assert all(not os.path.exists(x) for x in claimed),claimed
assert row.get('reclaimed') is True,row
PY
sed -n '1,360p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorReaperTests.swift >"$ROOT/SimulatorReaperTests.swift.excerpt"
sed -n '1,300p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorLeaseTests.swift >"$ROOT/SimulatorLeaseTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
