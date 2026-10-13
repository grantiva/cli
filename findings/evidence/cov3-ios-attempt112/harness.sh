#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt112";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt112-ios";U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$A" ]]||exit 73;mkdir -p "$ROOT";rsync -a --exclude .grantiva "$SRC/" "$A/";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$A/grantiva.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: $U1
bundle_id: com.kylebrowning.Landmarks
YAML
cat >"$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"$GRANTIVA runner start --json --bundle-id com.kylebrowning.Landmarks --simulator $U1 --platform ios --detach"},
 {"_shell":"xcrun simctl launch $U1 com.kylebrowning.Landmarks"},
 {"_shell":"for n in {1..20}; do $GRANTIVA hierarchy --udid $U1 --format json > $ROOT/readiness-\$n.json 2> $ROOT/readiness-\$n.err && rg -q Landmarks $ROOT/readiness-\$n.json && exit 0; sleep 1; done; exit 1"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Landmarks"},{"swipe":"up"},{"swipe":"up"},{"swipe":"up"},{"swipe":"up"},{"swipe":"up"},{"tap":"Mount \\"Denali\\""}]}},"_save":"quoted-script.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"after-tree.json"},
 {"method":"tools/list","params":{}}
]
JSON
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >>"$ROOT/cleanup-stop.out" 2>>"$ROOT/cleanup-stop.err")||true; };trap cleanup EXIT
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_u1=$U1; } >"$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios;echo $? >"$ROOT/mcp.exit"
python3 - "$ROOT" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);assert int((r/'mcp.exit').read_text())==0
j=json.load(open(r/'mcp'/'quoted-script.json'));assert not j['result'].get('isError',False);t=j['result']['content'][0]['text'];assert 'Mount "Denali"' in t and '7 steps' in t
tree=json.load(open(r/'mcp'/'after-tree.json'));assert 'Mount \\"Denali\\"' in tree['result']['content'][0]['text']
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
