#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt91"
SRC=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/ios
PRIVATE=/private/tmp/cov3-ios-attempt91;ALIAS=/tmp/cov3-ios-attempt91;U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$PRIVATE" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$PRIVATE/";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
P=0
cleanup(){ if ((P>1))&&kill -0 $P 2>/dev/null;then kill -INT $P 2>/dev/null;fi;(cd "$PRIVATE"&&"$GRANTIVA" runner stop --json >"$ROOT/cleanup-stop.out" 2>"$ROOT/cleanup-stop.err")||true; }
trap cleanup EXIT
cat >"$ROOT/requests.json" <<'JSON'
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},{"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"},{"method":"tools/list","params":{}}]
JSON
cat >"$ROOT/after-kill.json" <<'JSON'
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"},{"method":"tools/list","params":{}}]
JSON
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_device_udid=$U1; } >"$ROOT/commands.txt"
find /tmp/grantiva-sessions -maxdepth 1 -name '*.owner.json' -type f -print0 2>/dev/null | xargs -0 cat 2>/dev/null | rg -q "$U1" && exit 72
(cd "$ALIAS"&&"$GRANTIVA" run --no-build --simulator "$U1" --flow .maestro/01-browse.yaml --keep-alive --ready-file "$ROOT/ready.json") >"$ROOT/parent.out" 2>"$ROOT/parent.err" & P=$!;echo $P >"$ROOT/parent.pid"
OWNER='';for n in {1..600};do OWNER=$(find /tmp/grantiva-sessions -maxdepth 1 -name '*.owner.json' -type f -print 2>/dev/null|xargs rg -l '"udid":"'$U1'"' 2>/dev/null|head -1);[[ -n "$OWNER" ]]&&break;sleep .1;done
[[ -n "$OWNER" ]]||exit 74;cp "$OWNER" "$ROOT/owner.json";R=$(jq -r '.runnerPid' "$OWNER");echo $R >"$ROOT/runner.pid"
for n in {1..600};do [[ -f "$ROOT/ready.json" ]]&&[[ $(jq -r .status "$ROOT/ready.json") == passed ]]&&break;sleep .1;done
[[ -f "$ROOT/ready.json" ]]||exit 75
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp-alias" "$ALIAS" -- "$GRANTIVA" mcp --project-dir "$ALIAS" --platform ios||exit 76
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp-private" "$PRIVATE" -- "$GRANTIVA" mcp --project-dir "$PRIVATE" --platform ios||exit 77
kill -9 $P;wait $P;echo $? >"$ROOT/parent-killed.exit.txt";P=0
for n in {1..100};do kill -0 $R 2>/dev/null||break;sleep .1;done
kill -0 $R 2>/dev/null&&exit 78
find /tmp/grantiva-sessions -maxdepth 1 -name "$R*" -print >"$ROOT/sidecars-after.txt"
SECONDS=0;(cd "$PRIVATE"&&"$GRANTIVA" hierarchy --udid "$U1" --timeout 10 --format json)>"$ROOT/hierarchy-after.out" 2>"$ROOT/hierarchy-after.err";echo $? >"$ROOT/hierarchy-after.exit.txt";echo $SECONDS >"$ROOT/hierarchy-after.seconds.txt"
(cd "$PRIVATE"&&"$GRANTIVA" runner dump-hierarchy --format json)>"$ROOT/dump-after.out" 2>"$ROOT/dump-after.err";echo $? >"$ROOT/dump-after.exit.txt"
python3 -I "$ROOT/client.py" "$ROOT/after-kill.json" "$ROOT/mcp-after" "$PRIVATE" -- "$GRANTIVA" mcp --project-dir "$PRIVATE" --platform ios||exit 79
jq -e '.projectDirectory=="'$PRIVATE'" and .detached==false and .grantivaPid=='$(cat "$ROOT/parent.pid") "$ROOT/owner.json" >/dev/null||exit 80
[[ ! -s "$ROOT/sidecars-after.txt" ]]||exit 81
jq -e '.result.isError==true' "$ROOT/mcp-after/tree.json" >/dev/null||exit 82
[[ $(cat "$ROOT/hierarchy-after.exit.txt") != 0 && $(cat "$ROOT/dump-after.exit.txt") != 0 ]]||exit 83
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
