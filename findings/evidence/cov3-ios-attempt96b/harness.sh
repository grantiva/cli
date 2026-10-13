#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt96b"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios;PRIVATE=/private/tmp/cov3-ios-attempt96b;ALIAS=/tmp/cov3-ios-attempt96b;U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$PRIVATE" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$PRIVATE/";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$ROOT/requests.json" <<'JSON'
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"},{"method":"tools/list","params":{}}]
JSON
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_device_udid=$U1; } >"$ROOT/commands.txt"
python3 - "$U1" <<'PY'||exit 72
import glob,json,sys
for p in glob.glob('/tmp/grantiva-sessions/*.owner.json'):
 try:d=json.load(open(p))
 except Exception:continue
 assert str(d.get('udid'))!=sys.argv[1],(p,d)
PY
cleanup(){ (cd "$PRIVATE"&&"$GRANTIVA" runner stop --json >"$ROOT/cleanup-stop.out" 2>"$ROOT/cleanup-stop.err")||true; }
trap cleanup EXIT
(cd "$ALIAS"&&"$GRANTIVA" runner start --detach --json --bundle-id com.kylebrowning.Landmarks --simulator "$U1" --platform ios)>"$ROOT/start.json" 2>"$ROOT/start.err"||exit 74
R=$(jq -r .pid "$ROOT/start.json");for n in {1..100};do [[ -f /tmp/grantiva-sessions/$R.owner.json ]]&&break;sleep .1;done;cp /tmp/grantiva-sessions/$R.owner.json "$ROOT/owner.json"||exit 75
READY=0
for n in {1..30};do
  (cd "$PRIVATE"&&"$GRANTIVA" hierarchy --udid "$U1" --format json)>"$ROOT/hierarchy-$n.json" 2>"$ROOT/hierarchy-$n.err";e=$?;echo $e >"$ROOT/hierarchy-$n.exit.txt"
  if ((e==0))&&rg -q Landmarks "$ROOT/hierarchy-$n.json";then cp "$ROOT/hierarchy-$n.json" "$ROOT/hierarchy.json";READY=1;break;fi
  sleep 1
done
((READY==1))||exit 76
(cd "$PRIVATE"&&"$GRANTIVA" runner dump-hierarchy --format json)>"$ROOT/dump.json" 2>"$ROOT/dump.err"||exit 77
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$PRIVATE" -- "$GRANTIVA" mcp --project-dir "$PRIVATE" --platform ios||exit 78
(cd "$PRIVATE"&&"$GRANTIVA" runner stop --json)>"$ROOT/stop.json" 2>"$ROOT/stop.err"||exit 79
jq -e '.detached==true and .projectDirectory=="'$PRIVATE'" and .runnerPid=='$R "$ROOT/owner.json" >/dev/null||exit 80
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
