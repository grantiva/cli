#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt6"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
APP="$SCRATCH/ios"
CLIENT="$SCRATCH/mcp/client.py"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
ROWS=(MCP-029 MCP-034 MCP-039 MCP-009 MCP-017 MCP-021 MCP-076 IOS-099 IOS-105 IOS-108 IOS-109 D2-31 D2-44)

if [[ -e "$ROOT" ]]; then
  print -u2 "refusing to overwrite existing attempt directory: $ROOT"
  exit 73
fi
mkdir -p "$ROOT/FALLBACK/mcp" "$ROOT/PRE/mcp" "$ROOT/LIVE/mcp"
for row in $ROWS; do mkdir -p "$ROOT/$row"; done

cat > "$ROOT/FALLBACK/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_build","arguments":{"simulator":"cov3-ios-26"}},"_timeout":900},
  {"method":"tools/call","params":{"name":"grantiva_run","arguments":{"simulator":"cov3-ios-26"}},"_timeout":900},
  {"method":"tools/call","params":{"name":"grantiva_test","arguments":{"simulator":"cov3-ios-26"}},"_timeout":900}
]
JSON
cat > "$ROOT/PRE/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/list","params":{}}
]
JSON
cat > "$ROOT/LIVE/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/list","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_timeout":120},
  {"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_timeout":120},
  {"method":"resources/read","params":{"uri":"grantiva://screenshot"},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Deep Links"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"left"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"up"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"sideways"}},"_timeout":120}
]
JSON

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "binary=$GRANTIVA"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_name=cov3-ios-26"
  echo "owned_device_udid=$U1"
  echo "fallback requests omit scheme but explicitly name the owned simulator"
  echo "readiness poll: grantiva hierarchy --udid $U1 --format json, max 60 attempts"
} > "$ROOT/commands.txt"

xcrun simctl list devices booted > "$ROOT/booted-before.txt" 2> "$ROOT/booted-before.err"
python3 -I "$CLIENT" "$ROOT/FALLBACK/requests.json" "$ROOT/FALLBACK/mcp" "$APP" -- "$GRANTIVA" mcp --project-dir "$APP" --platform ios > "$ROOT/FALLBACK/client.out" 2> "$ROOT/FALLBACK/client.err"
fallback_rc=$?
python3 -I "$CLIENT" "$ROOT/PRE/requests.json" "$ROOT/PRE/mcp" "$APP" -- "$GRANTIVA" mcp --project-dir "$APP" --platform ios > "$ROOT/PRE/client.out" 2> "$ROOT/PRE/client.err"
pre_rc=$?
(cd "$APP" && "$GRANTIVA" runner start --detach --simulator "$U1" --bundle-id com.kylebrowning.Landmarks --json) > "$ROOT/start.out" 2> "$ROOT/start.err"
start_rc=$?
ready=1
for n in {1..60}; do
  (cd "$APP" && "$GRANTIVA" hierarchy --udid "$U1" --format json) > "$ROOT/ready-$n.out" 2> "$ROOT/ready-$n.err"
  ready=$?
  print "readiness_attempt=$n exit=$ready" >> "$ROOT/commands.txt"
  (( ready == 0 )) && break
  sleep 1
done
python3 -I "$CLIENT" "$ROOT/LIVE/requests.json" "$ROOT/LIVE/mcp" "$APP" -- "$GRANTIVA" mcp --project-dir "$APP" --platform ios > "$ROOT/LIVE/client.out" 2> "$ROOT/LIVE/client.err"
live_rc=$?
(cd "$APP" && "$GRANTIVA" runner dump-hierarchy --udid "$U1" --format json) > "$ROOT/dump.out" 2> "$ROOT/dump.err"
dump_rc=$?
(cd "$APP" && "$GRANTIVA" runner stop --json) > "$ROOT/stop.out" 2> "$ROOT/stop.err"
stop_rc=$?
xcrun simctl list devices booted > "$ROOT/booted-after.txt" 2> "$ROOT/booted-after.err"
print "fallback=$fallback_rc pre=$pre_rc start=$start_rc ready=$ready live=$live_rc dump=$dump_rc stop=$stop_rc" >> "$ROOT/commands.txt"

for row in $ROWS; do
  cp "$ROOT/commands.txt" "$ROOT/$row/commands.txt"
  cp "$ROOT/FALLBACK/mcp/transcript.txt" "$ROOT/$row/fallback-transcript.txt"
  cp "$ROOT/PRE/mcp/transcript.txt" "$ROOT/$row/pre-transcript.txt"
  cp "$ROOT/LIVE/mcp/transcript.txt" "$ROOT/$row/live-transcript.txt"
done

(( fallback_rc == 0 && pre_rc == 0 && start_rc == 0 && ready == 0 && live_rc == 0 && dump_rc == 0 && stop_rc == 0 ))
