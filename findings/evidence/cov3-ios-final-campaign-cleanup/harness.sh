#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-final-campaign-cleanup"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
U2=1B1102EC-224B-4EF7-937E-370A0DC317DA
[[ ! -e "$ROOT" ]] || { print -u2 refusing-overwrite; exit 73; }
mkdir -p "$ROOT"
cp "$0" "$ROOT/harness.sh"

xcrun simctl list devices -j >"$ROOT/devices-before.json" 2>"$ROOT/devices-before.err" || exit 74
"$GRANTIVA" simulator sessions --json >"$ROOT/sessions-before.json" 2>"$ROOT/sessions-before.err" || exit 75
ps -axo pid=,ppid=,state=,command= >"$ROOT/processes-before.txt"

python3 -I - "$ROOT/devices-before.json" "$ROOT/sessions-before.json" "$ROOT/processes-before.txt" "$U1" "$U2" <<'PY' || exit 76
import json,sys
dev=json.load(open(sys.argv[1])); ses=json.load(open(sys.argv[2])); procs=open(sys.argv[3]).read(); u1,u2=sys.argv[4:]
flat=[x for rows in dev['devices'].values() for x in rows]
expected={u1:'cov3-ios-26',u2:'cov3-ios-27'}
for u,n in expected.items():
 hits=[x for x in flat if x.get('udid')==u]
 assert len(hits)==1 and hits[0].get('name')==n,(u,hits)
 assert not [p for p in procs.splitlines() if u in p and ('grantiva-runner' in p or 'WebDriverAgent' in p or 'xcodebuild' in p)],u
rows=ses if isinstance(ses,list) else ses.get('sessions',[])
ours=[x for x in rows if x.get('sessionId')=='cov3-ios']
assert ours and {x.get('udid') for x in ours}=={u1,u2},ours
assert not [x for x in ours if x.get('udid') not in expected],ours
PY

{
 print -r -- "campaign_owned_u1=$U1 name=cov3-ios-26"
 print -r -- "campaign_owned_u2=$U2 name=cov3-ios-27"
 print -r -- 'normal targeted teardown only; no --force and no --all'
} >"$ROOT/commands.txt"

"$GRANTIVA" simulator teardown --udid "$U1" --json >"$ROOT/u1-teardown.json" 2>"$ROOT/u1-teardown.err"; R1=$?
print -r -- "$R1" >"$ROOT/u1-teardown.exit"
"$GRANTIVA" simulator teardown --udid "$U2" --json >"$ROOT/u2-teardown.json" 2>"$ROOT/u2-teardown.err"; R2=$?
print -r -- "$R2" >"$ROOT/u2-teardown.exit"

xcrun simctl list devices -j >"$ROOT/devices-after.json" 2>"$ROOT/devices-after.err" || exit 77
xcrun simctl list devices booted -j >"$ROOT/booted-after.json" 2>"$ROOT/booted-after.err" || exit 78
"$GRANTIVA" simulator sessions --json >"$ROOT/sessions-after.json" 2>"$ROOT/sessions-after.err" || exit 79
ps -axo pid=,ppid=,state=,command= >"$ROOT/processes-after.txt"

python3 -I - "$ROOT" "$U1" "$U2" "$R1" "$R2" <<'PY' || exit 80
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]); u1,u2=sys.argv[2:4]; exits=list(map(int,sys.argv[4:]))
assert exits==[0,0],exits
dev=json.load(open(r/'devices-after.json')); flat=[x for rows in dev['devices'].values() for x in rows]
assert not [x for x in flat if x.get('udid') in {u1,u2}],flat
ses=json.load(open(r/'sessions-after.json')); rows=ses if isinstance(ses,list) else ses.get('sessions',[])
assert not [x for x in rows if x.get('udid') in {u1,u2} or x.get('sessionId')=='cov3-ios'],rows
procs=(r/'processes-after.txt').read_text(errors='replace')
assert not [p for p in procs.splitlines() if u1 in p or u2 in p],procs
boot=json.load(open(r/'booted-after.json')); b=[x for rows in boot['devices'].values() for x in rows]
(r/'blocked-no-simulator-rows.json').write_text(json.dumps({
 'CLI-083':'blocked owner simulator booted' if b else 'guard now reachable; parent must adjudicate',
 'B-C21.1':'blocked owner simulator booted' if b else 'guard now reachable; parent must adjudicate',
 'bootedDevices':[{'name':x.get('name'),'udid':x.get('udid'),'state':x.get('state')} for x in b]
},indent=2)+'\n')
PY

date -u +finished_utc=%Y-%m-%dT%H:%M:%SZ >>"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
