#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt8"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
APP="$SCRATCH/ios"
CLIENT="$SCRATCH/mcp/client.py"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
ROWS=(MCP-013 IOS-104 B2-K78 D2-36)

if [[ -e "$ROOT" ]]; then
  print -u2 "refusing to overwrite existing attempt directory: $ROOT"
  exit 73
fi
mkdir -p "$ROOT/LIVE/mcp"
for row in $ROWS; do mkdir -p "$ROOT/$row"; done

cat > "$ROOT/LIVE/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"heart"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Landmarks"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Golden Gate Bridge"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Edit"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Name"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":" Renamed"}},"_timeout":120}
]
JSON

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "binary=$GRANTIVA"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_name=cov3-ios-26"
  echo "owned_device_udid=$U1"
} > "$ROOT/commands.txt"

xcrun simctl terminate "$U1" com.kylebrowning.Landmarks > "$ROOT/reset-terminate.out" 2> "$ROOT/reset-terminate.err"
xcrun simctl launch "$U1" com.kylebrowning.Landmarks > "$ROOT/reset-launch.out" 2> "$ROOT/reset-launch.err"
reset_rc=$?
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
(cd "$APP" && "$GRANTIVA" runner stop --json) > "$ROOT/stop.out" 2> "$ROOT/stop.err"
stop_rc=$?
print "reset=$reset_rc start=$start_rc ready=$ready live=$live_rc stop=$stop_rc" >> "$ROOT/commands.txt"

for row in $ROWS; do
  cp "$ROOT/commands.txt" "$ROOT/$row/commands.txt"
  cp "$ROOT/LIVE/mcp/transcript.txt" "$ROOT/$row/transcript.txt"
done

(( reset_rc == 0 && start_rc == 0 && ready == 0 && live_rc == 0 && stop_rc == 0 ))
