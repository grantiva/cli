#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt11b"
BASE=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
SOURCE="$BASE/ios"
SCRATCH="$BASE/attempt11b-ios"
CLIENT="$WT/findings/evidence/cov3-ios/attempt11-client.py"
U1=563907E1-703D-4322-AE5F-FC3B06D03143

if [[ -e "$ROOT" || -e "$SCRATCH" ]]; then
  print -u2 "refusing to overwrite existing attempt11b output or scratch"
  exit 73
fi
mkdir -p "$ROOT/B3-L14.1/mcp"
cp "$0" "$ROOT/harness.sh"
cp "$CLIENT" "$ROOT/client.py"
rsync -a --exclude '.grantiva' "$SOURCE/" "$SCRATCH/"

cat > "$ROOT/B3-L14.1/requests.json" <<JSON
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_build","arguments":{"simulator":"cov3-ios-26"}},"_timeout":8,"_cancel_after":2.0},
  {"_tracked_ps":"after-build-response"},
  {"_sleep":5},
  {"_pstree":"five-seconds-after-cancel"},
  {"_tracked_ps":"five-seconds-after-cancel"},
  {"method":"tools/list","params":{}}
]
JSON

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "binary=$GRANTIVA"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_name=cov3-ios-26"
  echo "owned_device_udid=$U1"
  echo "fresh_project_copy=$SCRATCH"
  echo "build cancellation delay=2s, then notifications/cancelled requestId=2"
  echo "command=python3 -I $CLIENT $ROOT/B3-L14.1/requests.json $ROOT/B3-L14.1/mcp $SCRATCH -- $GRANTIVA mcp --project-dir $SCRATCH --platform ios"
} > "$ROOT/B3-L14.1/commands.txt"

python3 -I "$CLIENT" "$ROOT/B3-L14.1/requests.json" "$ROOT/B3-L14.1/mcp" "$SCRATCH" -- "$GRANTIVA" mcp --project-dir "$SCRATCH" --platform ios > "$ROOT/B3-L14.1/client.out" 2> "$ROOT/B3-L14.1/client.err"
rc=$?
print "client_exit=$rc" >> "$ROOT/B3-L14.1/commands.txt"
exit $rc
