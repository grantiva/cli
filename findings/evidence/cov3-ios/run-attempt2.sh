#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt2"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
APP="$SCRATCH/ios"
CLIENT="$SCRATCH/mcp/client.py"
U1=563907E1-703D-4322-AE5F-FC3B06D03143

if [[ -e "$ROOT" ]]; then
  print -u2 "refusing to overwrite existing attempt directory: $ROOT"
  exit 73
fi
mkdir -p "$ROOT/N3-04/mcp"

cat > "$ROOT/N3-04/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_build","arguments":{"scheme":"Landmarks (UI Testing)","simulator":"cov3-ios-26"}},"_timeout":900},
  {"method":"tools/call","params":{"name":"grantiva_run","arguments":{"scheme":"Landmarks (UI Testing)","simulator":"cov3-ios-26"}},"_timeout":900},
  {"method":"tools/call","params":{"name":"grantiva_test","arguments":{"scheme":"Landmarks (UI Testing)","simulator":"cov3-ios-26"}},"_timeout":900},
  {"method":"tools/call","params":{"name":"grantiva_sim_boot","arguments":{"name":"cov3-ios-26"}},"_timeout":300}
]
JSON

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "binary=$GRANTIVA"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_name=cov3-ios-26"
  echo "owned_device_udid=$U1"
  echo "app=$APP"
  echo "client=$CLIENT"
  echo "command=python3 -I $CLIENT $ROOT/N3-04/requests.json $ROOT/N3-04/mcp $APP -- $GRANTIVA mcp --project-dir $APP --platform ios"
} > "$ROOT/N3-04/commands.txt"

xcrun simctl list devices booted > "$ROOT/N3-04/booted-before.txt" 2> "$ROOT/N3-04/booted-before.err"
python3 -I "$CLIENT" "$ROOT/N3-04/requests.json" "$ROOT/N3-04/mcp" "$APP" -- "$GRANTIVA" mcp --project-dir "$APP" --platform ios > "$ROOT/N3-04/client.out" 2> "$ROOT/N3-04/client.err"
rc=$?
xcrun simctl list devices booted > "$ROOT/N3-04/booted-after.txt" 2> "$ROOT/N3-04/booted-after.err"
{
  echo "exit=$rc"
  echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$ROOT/N3-04/commands.txt"
exit $rc
