#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt4"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
APP="$SCRATCH/ios"
CLIENT="$SCRATCH/mcp/client.py"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
ROWS=(MCP-001 MCP-009 MCP-017 MCP-021 MCP-042 MCP-076 IOS-101 IOS-106 IOS-108 IOS-109 X-020)

if [[ -e "$ROOT" ]]; then
  print -u2 "refusing to overwrite existing attempt directory: $ROOT"
  exit 73
fi
mkdir -p "$ROOT/BATCH/mcp"
for row in $ROWS; do mkdir -p "$ROOT/$row"; done

cat > "$ROOT/BATCH/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/list","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{"format":"file"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_timeout":120},
  {"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_timeout":120},
  {"method":"resources/read","params":{"uri":"grantiva://screenshot"},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Deep Links"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"left"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"sideways"}},"_timeout":120}
]
JSON

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "binary=$GRANTIVA"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_name=cov3-ios-26"
  echo "owned_device_udid=$U1"
  echo "start=$GRANTIVA runner start --detach --simulator $U1 --bundle-id com.kylebrowning.Landmarks --json"
  echo "client=python3 -I $CLIENT $ROOT/BATCH/requests.json $ROOT/BATCH/mcp $APP -- $GRANTIVA mcp --project-dir $APP --platform ios"
  echo "stop=$GRANTIVA runner stop --json"
  echo "request map: 2=tools/list; 3=tree; 4=list audit; 5-6=screenshots; 7=context; 8-9=resources; 10=tap Deep Links; 11=Deep Links audit; 12=tap Gesture Lab; 13=left swipe; 14=invalid swipe"
} > "$ROOT/BATCH/commands.txt"

xcrun simctl list devices booted > "$ROOT/BATCH/booted-before.txt" 2> "$ROOT/BATCH/booted-before.err"
(cd "$APP" && "$GRANTIVA" runner start --detach --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --json) > "$ROOT/BATCH/start.out" 2> "$ROOT/BATCH/start.err"
start_rc=$?
python3 -I "$CLIENT" "$ROOT/BATCH/requests.json" "$ROOT/BATCH/mcp" "$APP" -- "$GRANTIVA" mcp --project-dir "$APP" --platform ios > "$ROOT/BATCH/client.out" 2> "$ROOT/BATCH/client.err"
client_rc=$?
(cd "$APP" && "$GRANTIVA" runner stop --json) > "$ROOT/BATCH/stop.out" 2> "$ROOT/BATCH/stop.err"
stop_rc=$?
xcrun simctl list devices booted > "$ROOT/BATCH/booted-after.txt" 2> "$ROOT/BATCH/booted-after.err"
print "start=$start_rc client=$client_rc stop=$stop_rc" >> "$ROOT/BATCH/commands.txt"

for row in $ROWS; do
  cp "$ROOT/BATCH/commands.txt" "$ROOT/$row/commands.txt"
  cp "$ROOT/BATCH/mcp/transcript.txt" "$ROOT/$row/transcript.txt"
  cp "$ROOT/BATCH/mcp/server.stderr" "$ROOT/$row/server.stderr"
done

(( start_rc == 0 && client_rc == 0 && stop_rc == 0 ))
