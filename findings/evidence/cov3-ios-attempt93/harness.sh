#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt93"
A=/private/tmp/cov3-ios-attempt93-empty
CLIENT="$WT/findings/evidence/cov3-ios-attempt25/client.py"
[[ ! -e "$ROOT" && ! -e "$A" ]] || exit 73
mkdir -p "$ROOT" "$A"
cp "$0" "$ROOT/harness.sh"
cp "$CLIENT" "$ROOT/client.py"
cat > "$ROOT/requests.json" <<'JSON'
[{"method":"initialize","params":{}},{"method":"tools/call","params":{"name":"grantiva_sim_boot","arguments":{"name":"no-such-sim"}},"_save":"missing.json"},{"method":"tools/list","params":{}}]
JSON
{ date -u +started_utc=%Y-%m-%dT%H:%M:%SZ; shasum -a 256 "$GRANTIVA" "$CLIENT"; echo device_free_missing_name; } > "$ROOT/commands.txt"
python3 -I "$ROOT/client.py" "$ROOT/requests.json" "$ROOT/mcp" "$A" -- "$GRANTIVA" mcp --project-dir "$A" --platform ios
e=$?
python3 - "$ROOT/mcp/missing.json" <<'PY' || exit 74
import json,sys
o=json.load(open(sys.argv[1]))
assert 'error' not in o and o['result']['isError'] is True,o
t=o['result']['content'][0]['text']
assert 'Error:' in t and 'no-such-sim' in t,t
PY
echo client_exit=$e >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"
exit $e
