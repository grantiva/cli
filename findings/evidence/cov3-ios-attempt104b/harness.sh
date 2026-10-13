#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt104b";SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;A=/private/tmp/cov3-ios-attempt104b;U1=563907E1-703D-4322-AE5F-FC3B06D03143;C="$WT/findings/evidence/cov3-ios/attempt104b-client.py";MCP="$WT/findings/evidence/cov3-ios-attempt25/client.py";SYNTH=''
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";cp "$C" "$ROOT/client.py";cp "$MCP" "$ROOT/mcp-client.py"
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >"$ROOT/cleanup-stop.out" 2>"$ROOT/cleanup-stop.err")||true;[[ -n "$SYNTH" ]]&&rm -f -- "$SYNTH";};trap cleanup EXIT
python3 - "$U1" <<'PY'||exit 74
import glob,json,sys
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:d=json.load(open(p))
 except:continue
 assert str(d.get('udid'))!=sys.argv[1],(p,d)
PY
cat >"$ROOT/requests.json" <<'JSON'
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"},{"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_save":"resource.json"},{"method":"tools/list","params":{}}]
JSON
jq -e 'length==4' "$ROOT/requests.json" >/dev/null||exit 72
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$C" "$MCP";echo owned_device_udid=$U1; }>"$ROOT/commands.txt"
python3 -I "$C" "$ROOT" "$A" "$GRANTIVA" "$U1"||exit 75
R=$(jq -r .owner.runnerPid "$ROOT/timeline.json");SYNTH=/tmp/grantiva-sessions/$R.owner.json
(cd "$A"&&"$GRANTIVA" runner stop --json >"$ROOT/stop.json" 2>"$ROOT/stop.err")||exit 76
find /tmp/grantiva-sessions -maxdepth 1 -name "$R*" -print >"$ROOT/sidecars-after-stop.txt"
cp "$ROOT/owner-before-stop.json" "$SYNTH";cp "$SYNTH" "$ROOT/synthetic-dead-owner.json"
(cd "$A"&&"$GRANTIVA" hierarchy --udid "$U1" --format json >"$ROOT/dead-hierarchy.out" 2>"$ROOT/dead-hierarchy.err");echo $? >"$ROOT/dead-hierarchy.exit"
(cd "$A"&&"$GRANTIVA" runner dump-hierarchy --format json >"$ROOT/dead-dump.out" 2>"$ROOT/dead-dump.err");echo $? >"$ROOT/dead-dump.exit"
python3 -I "$MCP" "$ROOT/requests.json" "$ROOT/dead-mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios||exit 77
[[ -e "$SYNTH" ]]&&echo present >"$ROOT/synthetic-after.txt"||echo absent >"$ROOT/synthetic-after.txt"
rm -f -- "$SYNTH";SYNTH=''
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
