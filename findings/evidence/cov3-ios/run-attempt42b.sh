#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios-at42b
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt42b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SRC="$BASE/ios"; SCRATCH="$BASE/attempt42b-ios"
K44='cov3-ios-at42b-shutdown iPhone 17'; N203='cov3-ios-at42b-runtime iPhone 17'; INFER='cov3-ios-at42b-no-model'; MODES='cov3-ios-at42b-modes iPhone 17'; RACE='cov3-ios-at42b-race iPhone 17'
if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then print -u2 'refusing overwrite attempt42b'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; rsync -a --exclude '.grantiva' "$SRC/" "$SCRATCH/"
xcrun simctl list devices --json > "$ROOT/simctl-before.json"
python3 -I - "$ROOT/simctl-before.json" "$K44" "$N203" "$INFER" "$MODES" "$RACE" <<'PY' || exit $?
import json,sys
d=json.load(open(sys.argv[1])); names={x.get('name') for a in d['devices'].values() for x in a}
bad=[n for n in sys.argv[2:] if n in names]
if bad: raise SystemExit('refusing pre-existing names: '+repr(bad))
PY
OWNED="$ROOT/owned-created.tsv"; : > "$OWNED"
cleanup_owned() {
  local name uuid current
  [[ -s "$OWNED" ]] || return 0
  xcrun simctl list devices --json > "$ROOT/cleanup-inventory.json" 2> "$ROOT/cleanup-inventory.err" || return 0
  while IFS=$'\t' read -r name uuid; do
    current=$(jq -r --arg n "$name" --arg u "$uuid" '[.devices[][]|select(.name==$n and .udid==$u)]|length' "$ROOT/cleanup-inventory.json")
    if [[ "$current" == 1 ]]; then
      "$GRANTIVA" simulator delete --name "$name" --json >> "$ROOT/cleanup.out" 2>> "$ROOT/cleanup.err" || true
    fi
  done < "$OWNED"
}
trap cleanup_owned EXIT
validate_owned() {
  local name=$1 uuid=$2 tag=$3
  python3 -I - "$uuid" <<'PY' || return $?
import sys,uuid
try: uuid.UUID(sys.argv[1])
except ValueError: raise SystemExit('invalid UUID: '+sys.argv[1])
PY
  xcrun simctl list devices --json > "$ROOT/$tag-simctl.json" || return $?
  [[ $(jq -r --arg n "$name" --arg u "$uuid" '[.devices[][]|select(.name==$n and .udid==$u)]|length' "$ROOT/$tag-simctl.json") == 1 ]] || return 76
  print -r -- "$name\t$uuid" >> "$OWNED"
}
cd "$SCRATCH"
runone() {
 local n=$1; shift; print -r -- "$*" > "$ROOT/$n.command.txt"
 python3 -I - "$ROOT/$n" "$@" <<'PY'
import json,subprocess,sys,time
p,*cmd=sys.argv[1:]; t=time.monotonic(); r=subprocess.run(cmd,capture_output=True,text=True)
open(p+'.out','w').write(r.stdout); open(p+'.err','w').write(r.stderr); open(p+'.exit.txt','w').write(str(r.returncode)+'\n')
open(p+'.elapsed.json','w').write(json.dumps({'seconds':time.monotonic()-t})+'\n')
PY
}
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "session_id=$GRANTIVA_SESSION_ID"
} > "$ROOT/commands.txt"

# B2-K44: freshly created owned simulator is explicitly Shutdown for every validation.
runone k44-ensure "$GRANTIVA" simulator ensure --name "$K44" --device-type 'iPhone 17' --runtime 26.0 --no-boot --json
K44U=$(jq -r .udid "$ROOT/k44-ensure.out"); print -r -- "$K44U" > "$ROOT/k44.udid"
validate_owned "$K44" "$K44U" k44-created || { print -u2 'invalid k44 owned mapping'; exit 75; }
xcrun simctl list devices --json | jq --arg u "$K44U" '[.devices[][]|select(.udid==$u)]' > "$ROOT/k44-before-runs.json"
[[ $(jq --arg n "$K44" '[.[]|select(.name==$n and .state=="Shutdown")]|length' "$ROOT/k44-before-runs.json") == 1 ]] || { print -u2 'k44 shutdown mapping mismatch'; exit 76; }
runone k44-missing-build "$GRANTIVA" run --simulator "$K44U" --flow missing.yaml
runone k44-missing-no-build "$GRANTIVA" run --no-build --simulator "$K44U" --flow missing.yaml
mkdir -p not-a-flow; runone k44-directory "$GRANTIVA" run --no-build --simulator "$K44U" --flow not-a-flow
cat > grantiva.yml <<YAML
scheme: "Landmarks (UI Testing)"
simulator: "$K44"
bundle_id: com.kylebrowning.Landmarks
flows: [configured-missing.yaml]
YAML
runone k44-configured "$GRANTIVA" run --no-build --simulator "$K44U"
xcrun simctl list devices --json | jq --arg u "$K44U" '[.devices[][]|select(.udid==$u)]' > "$ROOT/k44-after-runs.json"
runone k44-delete "$GRANTIVA" simulator delete --name "$K44" --json

# N2-03 runtime spelling, reuse, mismatch and uninferable-name cases.
runone n203-create "$GRANTIVA" simulator ensure --name "$N203" --device-type 'iPhone 17' --runtime 26.0 --no-boot --json
N203U=$(jq -r .udid "$ROOT/n203-create.out"); print -r -- "$N203U" > "$ROOT/n203.udid"
validate_owned "$N203" "$N203U" n203-created || { print -u2 'invalid n203 owned mapping'; exit 75; }
xcrun simctl list devices --json | jq --arg u "$N203U" --arg n "$N203" '[.devices[][]|select(.udid==$u and .name==$n)]' > "$ROOT/n203-created-mapping.json"
[[ $(jq length "$ROOT/n203-created-mapping.json") == 1 ]] || { print -u2 'n203 mapping mismatch'; exit 76; }
runone n203-reuse "$GRANTIVA" simulator ensure --name "$N203" --device-type 'iPhone 17' --runtime 'iOS 26.0' --no-boot --json
runone n203-mismatch "$GRANTIVA" simulator ensure --name "$N203" --runtime 27.0 --no-boot --json
runone n203-infer-version "$GRANTIVA" simulator ensure --name "$INFER" --runtime 26.0 --no-boot --json
runone n203-infer-name "$GRANTIVA" simulator ensure --name "$INFER" --runtime 'iOS 26.0' --no-boot --json
runone n203-delete "$GRANTIVA" simulator delete --name "$N203" --json

# IOS-155 three output modes on a row-owned booted device, reusing it between teardown calls.
runone modes-ensure "$GRANTIVA" simulator ensure --name "$MODES" --device-type 'iPhone 17' --runtime 26.0 --json
MODESU=$(jq -r .udid "$ROOT/modes-ensure.out"); print -r -- "$MODESU" > "$ROOT/modes.udid"
validate_owned "$MODES" "$MODESU" modes-created || { print -u2 'invalid modes owned mapping'; exit 75; }
xcrun simctl list devices --json | jq --arg u "$MODESU" --arg n "$MODES" '[.devices[][]|select(.udid==$u and .name==$n)]' > "$ROOT/modes-created-mapping.json"
[[ $(jq length "$ROOT/modes-created-mapping.json") == 1 ]] || { print -u2 'modes mapping mismatch'; exit 76; }
runone modes-plain "$GRANTIVA" simulator teardown --udid "$MODESU" --force --json
runone modes-reensure1 "$GRANTIVA" simulator ensure --name "$MODES" --json
MODESU=$(jq -r .udid "$ROOT/modes-reensure1.out"); validate_owned "$MODES" "$MODESU" modes-reensure1 || { print -u2 'invalid modes reensure1 mapping'; exit 75; }
runone modes-quiet "$GRANTIVA" simulator teardown --udid "$MODESU" --force --json --quiet
runone modes-reensure2 "$GRANTIVA" simulator ensure --name "$MODES" --json
MODESU=$(jq -r .udid "$ROOT/modes-reensure2.out"); validate_owned "$MODES" "$MODESU" modes-reensure2 || { print -u2 'invalid modes reensure2 mapping'; exit 75; }
runone modes-verbose "$GRANTIVA" simulator teardown --udid "$MODESU" --force --json --verbose
runone modes-delete "$GRANTIVA" simulator delete --name "$MODES" --json

# D2-21 concurrent same-name ensure and session-scoped teardown.
print -r -- "$GRANTIVA simulator ensure --name $RACE --device-type iPhone 17 --runtime 26.0 --json" > "$ROOT/race.command.txt"
"$GRANTIVA" simulator ensure --name "$RACE" --device-type 'iPhone 17' --runtime 26.0 --json > "$ROOT/race-a.out" 2> "$ROOT/race-a.err" & A=$!
"$GRANTIVA" simulator ensure --name "$RACE" --device-type 'iPhone 17' --runtime 26.0 --json > "$ROOT/race-b.out" 2> "$ROOT/race-b.err" & B=$!
wait $A; print -r -- "$?" > "$ROOT/race-a.exit.txt"; wait $B; print -r -- "$?" > "$ROOT/race-b.exit.txt"
RACEU=$(jq -r .udid "$ROOT/race-a.out"); print -r -- "$RACEU" > "$ROOT/race.udid"
validate_owned "$RACE" "$RACEU" race-created || { print -u2 'invalid race owned mapping'; exit 75; }
xcrun simctl list devices --json | jq --arg u "$RACEU" --arg n "$RACE" '[.devices[][]|select(.udid==$u and .name==$n)]' > "$ROOT/race-created-mapping.json"
[[ $(jq length "$ROOT/race-created-mapping.json") == 1 ]] || { print -u2 'race mapping mismatch'; exit 76; }
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/created.json" "$ROOT/created-ledger-during.json" || exit $?
cp "$GRANTIVA_RUNNER_HOME/simulator-capacity/sessions.json" "$ROOT/sessions-ledger-during.json" || exit $?
python3 -I - "$ROOT/created-ledger-during.json" "$ROOT/sessions-ledger-during.json" "$RACE" "$RACEU" "$GRANTIVA_SESSION_ID" <<'PY' || exit $?
import json,sys
created,sessions,name,udid,sid=sys.argv[1:]
c=json.load(open(created)); s=json.load(open(sessions))
assert len([x for x in c if x.get('name')==name and x.get('udid')==udid])==1
owned=[x for x in s if x.get('sessionId')==sid]
assert len(owned)==1 and owned[0].get('name')==name and owned[0].get('udid')==udid, owned
PY
xcrun simctl list devices --json > "$ROOT/simctl-before-session-teardown.json"
runone session-teardown "$GRANTIVA" simulator teardown --session-id "$GRANTIVA_SESSION_ID" --json
xcrun simctl list devices --json > "$ROOT/simctl-after.json"
python3 -I - "$ROOT/simctl-after.json" "$K44" "$N203" "$INFER" "$MODES" "$RACE" <<'PY' || exit $?
import json,sys
d=json.load(open(sys.argv[1])); names={x.get('name') for a in d['devices'].values() for x in a}
left=[n for n in sys.argv[2:] if n in names]
if left: raise SystemExit('owned attempt42 devices remain: '+repr(left))
PY
echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
