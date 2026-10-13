#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios; ROOT="$WT/findings/evidence/cov3-ios-attempt131"; SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios; A1=/private/tmp/cov3-ios-attempt131-u1; A2=/private/tmp/cov3-ios-attempt131-u2; U1=563907E1-703D-4322-AE5F-FC3B06D03143; U2=1B1102EC-224B-4EF7-937E-370A0DC317DA; CLIENT="$WT/findings/evidence/cov3-ios/attempt131-helper.py"
[[ ! -e "$ROOT" && ! -e "$A1" && ! -e "$A2" ]]||exit 73; mkdir -p "$ROOT"; rsync -a --exclude .grantiva "$SRC/" "$A1/"; rsync -a --exclude .grantiva "$SRC/" "$A2/"; cp "$0" "$ROOT/harness.sh"; cp "$CLIENT" "$ROOT/helper.py"
cleanup(){ (cd "$A1"&&"$GRANTIVA" runner stop --json)>>"$ROOT/cleanup-u1.out" 2>>"$ROOT/cleanup-u1.err"||true;(cd "$A2"&&"$GRANTIVA" runner stop --json)>>"$ROOT/cleanup-u2.out" 2>>"$ROOT/cleanup-u2.err"||true; };trap cleanup EXIT
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_u1=$U1 owned_u2=$U2;}>"$ROOT/commands.txt"
(cd "$A2"&&"$GRANTIVA" runner start --detach --json --simulator "$U2" --bundle-id com.kylebrowning.Landmarks --platform ios)>"$ROOT/u2-start.json" 2>"$ROOT/u2-start.err"||exit 74
READY=0;for n in {1..80};do (cd "$A2"&&"$GRANTIVA" hierarchy --format json)>"$ROOT/u2-ready-$n.json" 2>"$ROOT/u2-ready-$n.err"&&rg -q Landmarks "$ROOT/u2-ready-$n.json"&&{ READY=1;break;};sleep .25;done;[[ $READY == 1 ]]||exit 75
python3 -I "$CLIENT" "$ROOT" "$A1" "$GRANTIVA" "$U1"||exit 76
"$GRANTIVA" simulator sessions --json >"$ROOT/sessions-before-force.json" 2>"$ROOT/sessions-before-force.err"||exit 77
"$GRANTIVA" simulator teardown --udid "$U1" --force --json >"$ROOT/u1-force.json" 2>"$ROOT/u1-force.err";echo $? >"$ROOT/u1-force.exit"
"$GRANTIVA" simulator sessions --json >"$ROOT/sessions-after-force.json" 2>"$ROOT/sessions-after-force.err"||exit 78
ps -axo pid=,ppid=,state=,command= >"$ROOT/processes-after-force.txt"
(cd "$A2"&&"$GRANTIVA" hierarchy --format json)>"$ROOT/u2-after-force.json" 2>"$ROOT/u2-after-force.err";echo $? >"$ROOT/u2-after-force.exit"
python3 - "$ROOT" "$U1" "$U2" <<'PY' || exit 79
import glob,json,os,pathlib,sys
r=pathlib.Path(sys.argv[1]);u1,u2=sys.argv[2:];out=json.load(open(r/'u1-force.json'));row=out[0] if isinstance(out,list) else out
assert int((r/'u1-force.exit').read_text())==0 and row.get('capacityRecordsCleared')==0,row
assert any(x.get('udid')==u1 and x.get('sessionId')=='cov3-ios' and x.get('reason') for x in row.get('capacityRecordsKept',[])),row
stale=(r/'restored-stale-path.txt').read_text().strip();assert stale in row.get('sessionFilesRemoved',[]) and not os.path.exists(stale),row
assert int((r/'u2-after-force.exit').read_text())==0
after=json.load(open(r/'sessions-after-force.json'));rows=after if isinstance(after,list) else after.get('sessions',[]);assert any(x.get('udid')==u2 and x.get('sessionId')=='cov3-ios' for x in rows),rows
assert not glob.glob('/tmp/grantiva-sessions/'+(r/'second-runner.pid').read_text().strip()+'*')
procs=(r/'processes-after-force.txt').read_text(errors='replace').splitlines()
assert not [x for x in procs if u1 in x and 'simctl diagnose' in x],procs
PY
sed -n '180,290p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorReaperTests.swift >"$ROOT/SimulatorReaperTests.swift.excerpt"
date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
