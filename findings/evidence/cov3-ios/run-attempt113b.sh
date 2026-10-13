#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt113b";A=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios/attempt113-ios;PRIOR="$WT/findings/evidence/cov3-ios-attempt113";CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && -d "$A/.grantiva/captures" && -d "$A/.grantiva/baselines" ]]||exit 73;[[ $(find "$A/.grantiva/captures" -name '*.png'|wc -l|tr -d ' ') == 5 && $(find "$A/.grantiva/baselines" -name '*.png'|wc -l|tr -d ' ') == 1 ]]||exit 74;mkdir -p "$ROOT";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$ROOT/requests.json" <<'JSON'
[
 {"method":"initialize","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}},"_save":"compare.json"},
 {"method":"tools/list","params":{}}
]
JSON
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$PRIOR/mixed-json.out"; } >"$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios;echo $? >"$ROOT/mcp.exit"
python3 - "$ROOT" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);assert int((r/'mcp.exit').read_text())==0;j=json.load(open(r/'mcp'/'compare.json'));assert not j['result'].get('isError',False);t=j['result']['content'][0]['text'];d=json.loads(t);assert d['passed'] is False and len(d['screens'])==5
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
