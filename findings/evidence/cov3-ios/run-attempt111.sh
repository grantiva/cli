#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios;ROOT="$WT/findings/evidence/cov3-ios-attempt111";BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios;SRC="$BASE/ios";A="$BASE/attempt111-ios";U1=563907E1-703D-4322-AE5F-FC3B06D03143;CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
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
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such Element"}},"_save":"01-fail-before-subscribe.json"},
 {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"diagonal"}},"_save":"02-rejected.json"},
 {"method":"resources/subscribe","params":{"uri":"grantiva://hierarchy"},"_save":"03-subscribe.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}},"_save":"04-success-subscribed.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such Element"}},"_save":"05-fail-subscribed.json"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Landmarks"},{"tap":"No Such Element"}]}},"_save":"06-partial-script.json"},
 {"method":"resources/unsubscribe","params":{"uri":"grantiva://hierarchy"},"_save":"07-unsubscribe.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}},"_save":"08-success-after-unsubscribe.json"},
 {"method":"tools/list","params":{}}
]
JSON
cleanup(){ (cd "$A"&&"$GRANTIVA" runner stop --json >>"$ROOT/cleanup-stop.out" 2>>"$ROOT/cleanup-stop.err")||true; };trap cleanup EXIT
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ;shasum -a 256 "$GRANTIVA" "$CLIENT";echo owned_u1=$U1; } >"$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios;echo $? >"$ROOT/mcp.exit"
python3 - "$ROOT" <<'PY'||exit 75
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);m=r/'mcp';assert int((r/'mcp.exit').read_text())==0
def j(n): return json.load(open(m/n))
assert j('01-fail-before-subscribe.json')['result'].get('isError') is True
assert j('02-rejected.json')['result'].get('isError') is True
assert not j('04-success-subscribed.json')['result'].get('isError',False)
assert j('05-fail-subscribed.json')['result'].get('isError') is True
assert j('06-partial-script.json')['result'].get('isError') is True
assert not j('08-success-after-unsubscribe.json')['result'].get('isError',False)
raw=[json.loads(x) for x in (m/'stdout.raw').read_text().splitlines() if x.strip()]
notes=[(i,x) for i,x in enumerate(raw) if x.get('method')=='notifications/resources/updated']
json.dump(notes,open(r/'notifications-indexed.json','w'),indent=2)
assert len(notes)==2
PY
echo finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)>>"$ROOT/commands.txt";find "$ROOT" -type f ! -name all-files-before-exit.sha256 -print0|sort -z|xargs -0 shasum -a 256 >"$ROOT/all-files-before-exit.sha256"
