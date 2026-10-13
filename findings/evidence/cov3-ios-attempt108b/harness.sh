#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt108b";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt108b-ios";EMPTY="$BASE/attempt108b-empty";DD="$BASE/attempt108b Derived Data";U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$A" && ! -e "$EMPTY" && ! -e "$DD" ]]||exit 73;mkdir -p "$ROOT" "$EMPTY";rsync -a --exclude .grantiva "$SRC/" "$A/";rsync -a --exclude .grantiva --exclude grantiva.yml "$SRC/" "$EMPTY/";cp "$0" "$ROOT/harness.sh";cp "$CLIENT" "$ROOT/client.py"
cat >"$A/grantiva.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: $U1
bundle_id: com.kylebrowning.Landmarks
YAML
mkdir -p "$A/.grantiva/flows";cp "$A/.maestro/01-browse.yaml" "$A/.grantiva/flows/seeded-state.yaml"
cat >"$EMPTY/config-ready.yml" <<YAML
scheme: "Landmarks (UI Testing)"
simulator: $U1
bundle_id: com.kylebrowning.Landmarks
derived_data_path: "$DD"
YAML
cat >"$ROOT/mcp-requests.json" <<JSON
[
 {"method":"initialize","params":{}},
 {"_shell":"test ! -e '$EMPTY/grantiva.yml'"},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{}},"_save":"before-config.json"},
 {"_shell":"xcrun simctl list devices -j > '$ROOT/mcp-before-config-devices.json'"},
 {"_shell":"cp '$EMPTY/config-ready.yml' '$EMPTY/grantiva.yml'"},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{}},"_save":"after-config.json"},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},
 {"method":"tools/list","params":{}}
]
JSON
xcrun simctl list devices -j >"$ROOT/before.json";python3 - "$ROOT/before.json" "$U1" <<'PY'||exit 74
import json,sys
d=json.load(open(sys.argv[1]));x=[x for a in d['devices'].values() for x in a if x.get('udid')==sys.argv[2]];assert len(x)==1 and x[0]['name']=='cov3-ios-26' and x[0]['state']=='Booted'
PY
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_u1=$U1; } >"$ROOT/commands.txt"
(cd "$A"&&"$GRANTIVA" build build --scheme 'Landmarks (UI Testing)' --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --derived-data-path "$DD" --json >"$ROOT/ios123-build.out" 2>"$ROOT/ios123-build.err");echo $? >"$ROOT/ios123-build.exit"
(cd "$A"&&"$GRANTIVA" build install --scheme 'Landmarks (UI Testing)' --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --derived-data-path "$DD" --no-launch --json >"$ROOT/ios124-install.out" 2>"$ROOT/ios124-install.err");echo $? >"$ROOT/ios124-install.exit"
jq -r .dataContainerPath "$ROOT/ios124-install.out" >"$ROOT/ios124-data-container.txt"
(cd "$A"&&"$GRANTIVA" run --no-build --flow .grantiva/flows/seeded-state.yaml --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --report-dir "$ROOT/ios124-report" >"$ROOT/ios124-run.out" 2>"$ROOT/ios124-run.err");echo $? >"$ROOT/ios124-run.exit"
python3 -I "$ROOT/client.py" "$ROOT/mcp-requests.json" "$ROOT/mcp" "$EMPTY" -- "$GRANTIVA" mcp --project-dir "$EMPTY" --platform ios;echo $? >"$ROOT/mcp.exit"
python3 - "$ROOT" "$U1" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);u=sys.argv[2]
assert all(int((r/p).read_text())==0 for p in ('ios123-build.exit','ios124-install.exit','ios124-run.exit','mcp.exit'))
b=json.load(open(r/'ios123-build.out'));assert b['success'] is True and b['destination'].endswith('id='+u)
i=json.load(open(r/'ios124-install.out'));assert i['bundleId']=='com.kylebrowning.Landmarks' and i['simulator']['udid']==u and i['dataContainerPath']==(r/'ios124-data-container.txt').read_text().strip()
before=json.load(open(r/'mcp'/'before-config.json'));assert before['result'].get('isError') is True and 'grantiva.yml' in before['result']['content'][0]['text']
assert json.load(open(r/'before.json'))['devices']==json.load(open(r/'mcp-before-config-devices.json'))['devices']
after=json.load(open(r/'mcp'/'after-config.json'));assert not after['result'].get('isError',False) and 'build succeeded' in after['result']['content'][0]['text'].lower()
context=json.load(open(r/'mcp'/'context.json'))['result']['content'][0]['text'];assert 'source: grantiva.yml' in context and 'Landmarks (UI Testing)' in context
PY
xcrun simctl list devices -j >"$ROOT/after.json";echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
