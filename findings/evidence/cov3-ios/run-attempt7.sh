#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios
unset GRANTIVA_API_KEY

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt7"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
APP="$SCRATCH/ios"
CLIENT="$SCRATCH/mcp/client.py"
U1=563907E1-703D-4322-AE5F-FC3B06D03143
ROWS=(MCP-005 IOS-102 IOS-103 D2-31 B2-K99)

if [[ -e "$ROOT" ]]; then
  print -u2 "refusing to overwrite existing attempt directory: $ROOT"
  exit 73
fi
mkdir -p "$ROOT/NAV/mcp" "$ROOT/POST/mcp"
for row in $ROWS; do mkdir -p "$ROOT/$row"; done

cat > "$ROOT/NAV/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"heart"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Landmarks"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Deep Links"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}},"_timeout":120}
]
JSON

{
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "binary=$GRANTIVA"
  shasum -a 256 "$GRANTIVA"
  echo "owned_device_name=cov3-ios-26"
  echo "owned_device_udid=$U1"
  echo "coordinate is derived from the live Gesture Pad frame in before-coordinate.json"
} > "$ROOT/commands.txt"

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
python3 -I "$CLIENT" "$ROOT/NAV/requests.json" "$ROOT/NAV/mcp" "$APP" -- "$GRANTIVA" mcp --project-dir "$APP" --platform ios > "$ROOT/NAV/client.out" 2> "$ROOT/NAV/client.err"
nav_rc=$?
(cd "$APP" && "$GRANTIVA" hierarchy --udid "$U1" --format json) > "$ROOT/before-coordinate.json" 2> "$ROOT/before-coordinate.err"
hier_rc=$?
xy=$(jq -r '[.. | objects | select((.label // .name // "") == "Gesture Pad") | .frame | [(.x + .width/2),(.y + .height/2)]] | first | @tsv' "$ROOT/before-coordinate.json")
x=${xy%%$'\t'*}
y=${xy#*$'\t'}
print "derived_coordinate=$x,$y" >> "$ROOT/commands.txt"
cat > "$ROOT/POST/requests.json" <<JSON
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"x":$x,"y":$y}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_timeout":120}
]
JSON
python3 -I "$CLIENT" "$ROOT/POST/requests.json" "$ROOT/POST/mcp" "$APP" -- "$GRANTIVA" mcp --project-dir "$APP" --platform ios > "$ROOT/POST/client.out" 2> "$ROOT/POST/client.err"
post_rc=$?
(cd "$APP" && "$GRANTIVA" hierarchy --udid "$U1" --format json) > "$ROOT/hierarchy.out" 2> "$ROOT/hierarchy.err"
hier2_rc=$?
(cd "$APP" && "$GRANTIVA" runner dump-hierarchy --udid "$U1" --format json) > "$ROOT/dump.out" 2> "$ROOT/dump.err"
dump_rc=$?
(cd "$APP" && "$GRANTIVA" runner stop --json) > "$ROOT/stop.out" 2> "$ROOT/stop.err"
stop_rc=$?
print "start=$start_rc ready=$ready nav=$nav_rc prehierarchy=$hier_rc post=$post_rc hierarchy=$hier2_rc dump=$dump_rc stop=$stop_rc" >> "$ROOT/commands.txt"

for row in $ROWS; do
  cp "$ROOT/commands.txt" "$ROOT/$row/commands.txt"
  cp "$ROOT/NAV/mcp/transcript.txt" "$ROOT/$row/nav-transcript.txt"
  cp "$ROOT/POST/mcp/transcript.txt" "$ROOT/$row/post-transcript.txt"
done

(( start_rc == 0 && ready == 0 && nav_rc == 0 && hier_rc == 0 && post_rc == 0 && hier2_rc == 0 && dump_rc == 0 && stop_rc == 0 ))
