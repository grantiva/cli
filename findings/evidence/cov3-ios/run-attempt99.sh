#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt99";BASE=/private/tmp/cov3-ios-attempt99;CFG="$BASE/config";EMPTY="$BASE/empty";CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py";N3='cov-ios-3 iPhone 17';N4='cov-ios-4 iPhone 17'
[[ ! -e "$ROOT" && ! -e "$BASE" ]]||exit 73;mkdir -p "$ROOT" "$CFG" "$EMPTY";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$CFG/grantiva.yml" <<'YAML'
scheme: "Landmarks (UI Testing)"
simulator: cov3-ios-26
bundle_id: com.kylebrowning.Landmarks
YAML
cp "$CFG/grantiva.yml" "$ROOT/grantiva.yml";xcrun simctl list devices -j >"$ROOT/before.json"
python3 - "$ROOT/before.json" "$N3" "$N4" <<'PY'||exit 74
import json,sys
d=json.load(open(sys.argv[1]));names={x.get('name') for a in d['devices'].values() for x in a};assert sys.argv[2] not in names and sys.argv[3] not in names
PY
cleanup(){
 xcrun simctl list devices -j >"$ROOT/cleanup-before.json" 2>"$ROOT/cleanup-before.err"||return
 python3 - "$ROOT/cleanup-before.json" "$N3" "$N4" >"$ROOT/cleanup-owned.txt" <<'PY'
import json,sys,re
d=json.load(open(sys.argv[1]));
for a in d['devices'].values():
 for x in a:
  if x.get('name') in sys.argv[2:] and re.fullmatch(r'[0-9A-F-]{36}',x.get('udid','')):print(x['udid'])
PY
 while IFS= read -r u;do [[ -z "$u" ]]||xcrun simctl delete "$u" >>"$ROOT/cleanup.out" 2>>"$ROOT/cleanup.err";done <"$ROOT/cleanup-owned.txt"
 xcrun simctl list devices -j >"$ROOT/cleanup-after.json" 2>"$ROOT/cleanup-after.err"||true
};trap cleanup EXIT
cat >"$ROOT/config-create.json" <<JSON
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_sim_ensure","arguments":{"name":"$N3"}},"_save":"ensure3.json"},{"method":"tools/call","params":{"name":"grantiva_sim_boot","arguments":{"name":"$N3"}},"_save":"boot3.json"},{"method":"tools/call","params":{"name":"grantiva_sim_ensure","arguments":{"name":"$N4"}},"_save":"ensure4.json"},{"method":"tools/list","params":{}}]
JSON
cat >"$ROOT/empty-reuse.json" <<JSON
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_sim_boot","arguments":{"name":"$N3"}},"_save":"boot3.json"},{"method":"tools/call","params":{"name":"grantiva_sim_ensure","arguments":{"name":"$N4"}},"_save":"ensure4.json"},{"method":"tools/list","params":{}}]
JSON
cat >"$ROOT/config-delete.json" <<JSON
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_sim_delete","arguments":{"name":"$N4"}},"_save":"delete4.json"},{"method":"tools/call","params":{"name":"grantiva_sim_delete","arguments":{"name":"$N3"}},"_save":"delete3.json"},{"method":"tools/list","params":{}}]
JSON
cat >"$ROOT/empty-recreate-delete.json" <<JSON
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_sim_ensure","arguments":{"name":"$N4"}},"_save":"ensure4.json"},{"method":"tools/call","params":{"name":"grantiva_sim_delete","arguments":{"name":"$N4"}},"_save":"delete4.json"},{"method":"tools/list","params":{}}]
JSON
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo exact_names=$N3,$N4; }>"$ROOT/commands.txt"
python3 -I "$CLIENT" "$ROOT/config-create.json" "$ROOT/config-create" "$CFG" -- "$GRANTIVA" mcp --project-dir "$CFG" --platform ios||exit 75
xcrun simctl list devices -j >"$ROOT/after-create.json"
python3 -I "$CLIENT" "$ROOT/empty-reuse.json" "$ROOT/empty-reuse" "$EMPTY" -- "$GRANTIVA" mcp --project-dir "$EMPTY" --platform ios||exit 76
python3 -I "$CLIENT" "$ROOT/config-delete.json" "$ROOT/config-delete" "$CFG" -- "$GRANTIVA" mcp --project-dir "$CFG" --platform ios||exit 77
python3 -I "$CLIENT" "$ROOT/empty-recreate-delete.json" "$ROOT/empty-recreate-delete" "$EMPTY" -- "$GRANTIVA" mcp --project-dir "$EMPTY" --platform ios||exit 78
xcrun simctl list devices -j >"$ROOT/after-commands.json"
python3 - "$ROOT/before.json" "$ROOT/after-commands.json" "$N3" "$N4" <<'PY'||exit 79
import json,sys
for p in sys.argv[1:3]:
 d=json.load(open(p));hits=[x for a in d['devices'].values() for x in a if x.get('name') in sys.argv[3:]];assert not hits,(p,hits)
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
