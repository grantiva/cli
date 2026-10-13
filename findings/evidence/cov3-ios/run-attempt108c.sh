#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt108c";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";EMPTY="$BASE/attempt108c-empty";DD="$BASE/attempt108b Derived Data";U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$EMPTY" && -d "$DD" ]]||exit 73;mkdir -p "$ROOT" "$EMPTY";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$ROOT/config-ready.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: $U1
bundle_id: com.kylebrowning.Landmarks
derived_data_path: "$DD"
YAML
cat >"$ROOT/requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"test -z \"\$(find '$EMPTY' -mindepth 1 -maxdepth 1 -print -quit)\""},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{}},"_save":"before-config.json"},
 {"_shell":"xcrun simctl list devices -j > '$ROOT/after-error-devices.json'"},
 {"_shell":"rsync -a --exclude .grantiva --exclude grantiva.yml '$SRC/' '$EMPTY/' && cp '$ROOT/config-ready.yml' '$EMPTY/grantiva.yml'"},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{}},"_save":"after-config.json"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},
 {"method":"tools/list","params":{}}
]
JSON
xcrun simctl list devices -j >"$ROOT/before.json";{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_u1=$U1; } >"$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$EMPTY" -- "$GRANTIVA" mcp --project-dir "$EMPTY" --platform ios;echo $? >"$ROOT/mcp.exit"
python3 - "$ROOT" "$U1" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);u=sys.argv[2]
assert int((r/'mcp.exit').read_text())==0
def identities(p):
 d=json.load(open(r/p));return sorted((x.get('name'),x.get('udid'),x.get('state')) for a in d['devices'].values() for x in a)
assert identities('before.json')==identities('after-error-devices.json')
before=json.load(open(r/'mcp'/'before-config.json'));assert before['result'].get('isError') is True and 'grantiva.yml not found' in before['result']['content'][0]['text']
after=json.load(open(r/'mcp'/'after-config.json'));assert not after['result'].get('isError',False) and 'Build succeeded' in after['result']['content'][0]['text'] and u in after['result']['content'][0]['text']
context=json.load(open(r/'mcp'/'context.json'))['result']['content'][0]['text'];assert 'source: grantiva.yml' in context and 'Landmarks (UI Testing)' in context and u in context
PY
xcrun simctl list devices -j >"$ROOT/after.json";echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
