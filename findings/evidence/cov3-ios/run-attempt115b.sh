#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios-115b
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt115b";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt115b-ios";NAME='cov3-ios-115b iPhone 17';U='';APP='/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt44-ios/round3 derived data/Build/Products/UITesting-iphonesimulator/Landmarks.app'
[[ ! -e "$ROOT" && ! -e "$A" && -d "$APP" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";xcrun simctl list devices -j >"$ROOT/before.json"
python3 - "$ROOT/before.json" "$NAME" <<'PY'||exit 74
import json,sys
d=json.load(open(sys.argv[1]));assert not any(x.get('name')==sys.argv[2] for a in d['devices'].values() for x in a)
PY
cleanup(){ "$GRANTIVA" simulator teardown --session-id cov3-ios-115b --json >>"$ROOT/cleanup.out" 2>>"$ROOT/cleanup.err"||true; };trap cleanup EXIT
"$GRANTIVA" simulator ensure --name "$NAME" --device-type "iPhone 17" --runtime "iOS 26.0" --json >"$ROOT/ensure.out" 2>"$ROOT/ensure.err"||exit 75;U=$(jq -r .udid "$ROOT/ensure.out");python3 - "$U" <<'PY'||exit 76
import re,sys
assert re.fullmatch(r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}',sys.argv[1])
PY
xcrun simctl install "$U" "$APP" >"$ROOT/install.out" 2>"$ROOT/install.err"||exit 78
cat >"$A/grantiva.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: $U
bundle_id: com.kylebrowning.Landmarks
YAML
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";echo owned_created_udid=$U; } >"$ROOT/commands.txt"
for i in 1 2 3;do
 (cd "$A"&&"$GRANTIVA" runner start --detach --json --bundle-id com.kylebrowning.Landmarks --simulator "$U" --platform ios) >"$ROOT/$i-start.out" 2>"$ROOT/$i-start.err";echo $? >"$ROOT/$i-start.exit"
 ready=0;for n in {1..30};do (cd "$A"&&"$GRANTIVA" hierarchy --format json >"$ROOT/$i-ready-$n.json" 2>"$ROOT/$i-ready-$n.err")&&rg -q Landmarks "$ROOT/$i-ready-$n.json"&&{ ready=1;break; };sleep 1;done;[[ $ready == 1 ]]||exit 79
 (cd "$A"&&"$GRANTIVA" runner stop --json) >"$ROOT/$i-stop.out" 2>"$ROOT/$i-stop.err";echo $? >"$ROOT/$i-stop.exit"
 ps -axo pid=,ppid=,state=,command= >"$ROOT/$i-ps-immediate.txt"
 sleep 60
 ps -axo pid=,ppid=,state=,command= >"$ROOT/$i-ps-60s.txt"
done
"$GRANTIVA" simulator teardown --session-id cov3-ios-115b --json >"$ROOT/teardown.out" 2>"$ROOT/teardown.err";echo $? >"$ROOT/teardown.exit";xcrun simctl list devices -j >"$ROOT/after.json"
python3 - "$ROOT" "$U" <<'PY'||exit 77
import json,pathlib,re,sys
r=pathlib.Path(sys.argv[1]);u=sys.argv[2]
for i in range(1,4):
 assert int((r/f'{i}-start.exit').read_text())==0 and int((r/f'{i}-stop.exit').read_text())==0
 for when in ('immediate','60s'):
  bad=[x for x in (r/f'{i}-ps-{when}.txt').read_text().splitlines() if u in x and re.search(r'grantiva-runner|xcodebuild|simctl\s+diagnose',x,re.I)]
  assert not bad,(i,when,bad)
assert int((r/'teardown.exit').read_text())==0
d=json.load(open(r/'after.json'));assert not any(x.get('udid')==u for a in d['devices'].values() for x in a)
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
