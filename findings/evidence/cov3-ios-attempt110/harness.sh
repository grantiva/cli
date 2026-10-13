#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt110";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt110-ios";U1=563907E1-703D-4322-AE5F-FC3B06D03143
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";mkdir -p "$A/.grantiva"
cat >"$A/grantiva.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: $U1
bundle_id: com.kylebrowning.Landmarks
YAML
cat >"$A/.grantiva/session.json" <<JSON
{"pid":999999,"port":8511,"wdaPort":8511,"bundleId":"com.example.Stale","udid":"$U1","platform":"ios","startedAt":"2026-01-01T00:00:00Z","state":"ready"}
JSON
cp "$A/.grantiva/session.json" "$ROOT/stale-session.json";kill -0 999999 2>"$ROOT/stale-pid.err";echo $? >"$ROOT/stale-pid.exit"
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >>"$ROOT/cleanup-stop.out" 2>>"$ROOT/cleanup-stop.err")||true; };trap cleanup EXIT
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA";echo owned_u1=$U1; } >"$ROOT/commands.txt"
(cd "$A"&&"$GRANTIVA" runner start --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios --detach >"$ROOT/start.out" 2>"$ROOT/start.err");echo $? >"$ROOT/start.exit"
for n in {1..20};do (cd "$A"&&"$GRANTIVA" hierarchy --format json >"$ROOT/ready-$n.json" 2>"$ROOT/ready-$n.err")&&rg -q Landmarks "$ROOT/ready-$n.json"&&break;sleep 1;done
cp "$A/.grantiva/session.json" "$ROOT/new-session.json"; (cd "$A"&&"$GRANTIVA" runner stop --json >"$ROOT/stop.out" 2>"$ROOT/stop.err");echo $? >"$ROOT/stop.exit"
python3 - "$ROOT" "$U1" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);u=sys.argv[2];old=json.load(open(r/'stale-session.json'));new=json.load(open(r/'new-session.json'))
assert int((r/'stale-pid.exit').read_text())!=0 and int((r/'start.exit').read_text())==0 and int((r/'stop.exit').read_text())==0
assert old['pid']==999999 and new['pid']!=old['pid'] and new['bundleId']=='com.kylebrowning.Landmarks' and new['udid']==u and new['state']=='ready' and new['port']>0
assert any('Landmarks' in p.read_text() for p in r.glob('ready-*.json'))
PY
test ! -e "$A/.grantiva/session.json"||exit 76;echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
