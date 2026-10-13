#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios; ROOT="$WT/findings/evidence/cov3-ios-attempt71b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios; SRC="$BASE/ios"; A="$BASE/attempt71b-ios"
APP="$BASE/attempt44-ios/round3 derived data/Build/Products/UITesting-iphonesimulator/Landmarks.app"
SID=cov3-ios-a71; PRE='cov3-ios-71-preexisting iPhone 17'; NEW='cov3-ios-71-created iPhone 17'
if [[ -e "$ROOT" || -e "$A" ]];then print -u2 'refusing overwrite attempt71b';exit 73;fi
mkdir -p "$ROOT";cp "$0" "$ROOT/harness.sh";rsync -a --exclude '.grantiva' "$SRC/" "$A/";[[ -d "$APP" ]]||exit 74
shasum -a 256 "$APP/Info.plist" "$APP/Landmarks" > "$ROOT/app-product.sha256"
cd "$A" || exit 74
"$GRANTIVA" simulator sessions --json > "$ROOT/sessions-preflight.json" 2> "$ROOT/sessions-preflight.err"
python3 - "$ROOT/sessions-preflight.json" "$SID" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); assert not any(x.get('sessionId')==sys.argv[2] for x in j if isinstance(x,dict)),j
PY
[[ $? -eq 0 ]] || exit 74
xcrun simctl list devices -j > "$ROOT/before.json"
python3 - "$ROOT/before.json" "$PRE" "$NEW" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); names={d.get('name') for ds in j['devices'].values() for d in ds}; assert not names.intersection(sys.argv[2:])
PY
PREU=$(xcrun simctl create "$PRE" 'iPhone 17' 'iOS 26.0'); print -r -- "$PREU" > "$ROOT/preexisting.udid"
xcrun simctl list devices -j > "$ROOT/after-direct-create.json"
python3 - "$ROOT/before.json" "$ROOT/after-direct-create.json" "$PRE" "$PREU" <<'PY'
import json,re,sys
b,a,n,u=sys.argv[1:];bj=json.load(open(b));aj=json.load(open(a));old={d['udid'] for ds in bj['devices'].values() for d in ds};f=[d for ds in aj['devices'].values() for d in ds if d['udid']==u];assert re.fullmatch(r'[0-9A-Fa-f-]{36}',u) and u not in old and len(f)==1 and f[0]['name']==n
PY
if [[ $? -ne 0 ]];then print -u2 'preexisting ownership validation failed';exit 75;fi
cleanup(){
 xcrun simctl list devices -j > "$ROOT/cleanup-before.json" 2> "$ROOT/cleanup-before.err"
 for pair in "$PRE|$PREU" "$NEW|${NEWU:-}";do n=${pair%%|*};u=${pair#*|};[[ -n $u ]]||continue; python3 - "$ROOT/cleanup-before.json" "$n" "$u" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]));f=[d for ds in j['devices'].values() for d in ds if d['udid']==sys.argv[3]];assert not f or(len(f)==1 and f[0]['name']==sys.argv[2]),f
PY
  [[ $? -ne 0 ]]||xcrun simctl delete "$u" >> "$ROOT/cleanup.out" 2>> "$ROOT/cleanup.err"
 done
 xcrun simctl list devices -j > "$ROOT/cleanup-after.json" 2> "$ROOT/cleanup-after.err"
}
trap cleanup EXIT
{ echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)";shasum -a 256 "$GRANTIVA";echo "session=$SID preexisting=$PREU"; } > "$ROOT/commands.txt"
run(){local n=$1;shift;print -r -- "$*" > "$ROOT/$n.command.txt";"$@" > "$ROOT/$n.out" 2> "$ROOT/$n.err";print -r -- "$?" > "$ROOT/$n.exit.txt";}
GRANTIVA_SESSION_ID=$SID run ensure-pre env GRANTIVA_SESSION_ID=$SID "$GRANTIVA" simulator ensure --name "$PRE" --json
(
 GRANTIVA_SESSION_ID=$SID "$GRANTIVA" simulator ensure --name "$NEW" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json > "$ROOT/ensure-new-a.out" 2> "$ROOT/ensure-new-a.err";echo $? > "$ROOT/ensure-new-a.exit.txt"
)&p1=$!
(
 GRANTIVA_SESSION_ID=$SID "$GRANTIVA" simulator ensure --name "$NEW" --device-type 'iPhone 17' --runtime 'iOS 26.0' --json > "$ROOT/ensure-new-b.out" 2> "$ROOT/ensure-new-b.err";echo $? > "$ROOT/ensure-new-b.exit.txt"
)&p2=$!
wait $p1;wait $p2
NEWU=$(python3 - "$ROOT/ensure-new-a.out" "$ROOT/ensure-new-b.out" <<'PY'
import json,sys
u=[json.load(open(p))['udid'] for p in sys.argv[1:]]
assert len(set(u))==1,u
print(u[0])
PY
)
print -r -- "$NEWU" > "$ROOT/created.udid"
xcrun simctl list devices -j > "$ROOT/after-ensures.json"
python3 - "$ROOT/before.json" "$ROOT/after-ensures.json" "$NEW" "$NEWU" <<'PY'
import json,re,sys
b,a,n,u=sys.argv[1:];old={d['udid'] for ds in json.load(open(b))['devices'].values() for d in ds};f=[d for ds in json.load(open(a))['devices'].values() for d in ds if d['udid']==u];assert re.fullmatch(r'[0-9A-Fa-f-]{36}',u) and u not in old and len(f)==1 and f[0]['name']==n
PY
if [[ $? -ne 0 ]];then print -u2 'created ownership validation failed';exit 76;fi
[[ $(<"$ROOT/ensure-new-a.exit.txt") == 0 && $(<"$ROOT/ensure-new-b.exit.txt") == 0 ]] || exit 76
python3 - "$ROOT/after-ensures.json" "$NEW" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]));f=[d for ds in j['devices'].values() for d in ds if d.get('name')==sys.argv[2]];assert len(f)==1,f
PY
[[ $? -eq 0 ]] || exit 76
GRANTIVA_SESSION_ID=$SID run install env GRANTIVA_SESSION_ID=$SID "$GRANTIVA" build install --no-build --app-file "$APP" --no-launch --simulator "$PREU" --platform ios --json
GRANTIVA_SESSION_ID=$SID run sessions env GRANTIVA_SESSION_ID=$SID "$GRANTIVA" simulator sessions --json
GRANTIVA_SESSION_ID=other run other-run env GRANTIVA_SESSION_ID=other "$GRANTIVA" run --no-build --flow .maestro/01-browse.yaml --simulator "$PREU" --platform ios
run unset-run env -u GRANTIVA_SESSION_ID "$GRANTIVA" run --no-build --flow .maestro/01-browse.yaml --simulator "$PREU" --platform ios
GRANTIVA_SESSION_ID=$SID run same-run env GRANTIVA_SESSION_ID=$SID "$GRANTIVA" run --no-build --flow .maestro/01-browse.yaml --simulator "$PREU" --platform ios --report-dir "$ROOT/same-report"
GRANTIVA_SESSION_ID=$SID run teardown env GRANTIVA_SESSION_ID=$SID "$GRANTIVA" simulator teardown --session-id "$SID" --json
xcrun simctl list devices -j > "$ROOT/after-teardown.json"
print -r -- "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 > "$ROOT/all-files-before-exit.sha256"
python3 - "$ROOT" "$PREU" "$NEWU" <<'PY'
from pathlib import Path
import json,sys
r=Path(sys.argv[1]);pre,new=sys.argv[2:];bad=[]
for n in ['ensure-pre','install','sessions','same-run','teardown']:
 if int((r/f'{n}.exit.txt').read_text())!=0:bad.append(n)
for n in ['other-run','unset-run']:
 if int((r/f'{n}.exit.txt').read_text())==0:bad.append(n)
j=json.load(open(r/'after-teardown.json'));m={d['udid']:d for ds in j['devices'].values() for d in ds}
if new in m:bad.append('created-not-deleted')
if pre not in m or m[pre]['state']!='Shutdown':bad.append(('preexisting',m.get(pre)))
print(bad);raise SystemExit(bool(bad))
PY
