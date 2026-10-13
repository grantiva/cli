#!/bin/zsh
set -u

export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios

WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt3"
SCRATCH=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-ios
APP="$SCRATCH/ios"
EMPTY="$SCRATCH/attempt3-empty"
CLIENT="$SCRATCH/mcp/client.py"
U1=563907E1-703D-4322-AE5F-FC3B06D03143

if [[ -e "$ROOT" ]]; then
  print -u2 "refusing to overwrite existing attempt directory: $ROOT"
  exit 73
fi
mkdir -p "$ROOT/MCP-044/mcp" "$ROOT/MCP-047/mcp" "$ROOT/MCP-048/mcp" "$EMPTY"

cat > "$ROOT/MCP-044/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_timeout":120}
]
JSON
cat > "$ROOT/MCP-047/requests.json" <<'JSON'
[
  {"method":"initialize","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_sim_list","arguments":{"filter":"booted"}},"_timeout":120},
  {"method":"tools/call","params":{"name":"grantiva_sim_list","arguments":{"filter":"all"}},"_timeout":120}
]
JSON
cp "$ROOT/MCP-047/requests.json" "$ROOT/MCP-048/requests.json"

run_client() {
  local row=$1
  local dir=$2
  {
    echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "binary=$GRANTIVA"
    echo "owned_device_name=cov3-ios-26"
    echo "owned_device_udid=$U1"
    echo "project_dir=$dir"
    echo "command=python3 -I $CLIENT $ROOT/$row/requests.json $ROOT/$row/mcp $dir -- $GRANTIVA mcp --project-dir $dir --platform ios"
  } > "$ROOT/$row/commands.txt"
  python3 -I "$CLIENT" "$ROOT/$row/requests.json" "$ROOT/$row/mcp" "$dir" -- "$GRANTIVA" mcp --project-dir "$dir" --platform ios > "$ROOT/$row/client.out" 2> "$ROOT/$row/client.err"
  local rc=$?
  echo "exit=$rc" >> "$ROOT/$row/commands.txt"
  return $rc
}

shasum -a 256 "$GRANTIVA" > "$ROOT/binary.sha256"
xcrun simctl list devices booted > "$ROOT/booted-before.txt" 2> "$ROOT/booted-before.err"
run_client MCP-044 "$APP"
r1=$?
run_client MCP-047 "$APP"
r2=$?
run_client MCP-048 "$EMPTY"
r3=$?
xcrun simctl list devices booted > "$ROOT/booted-after.txt" 2> "$ROOT/booted-after.err"
print "MCP-044=$r1 MCP-047=$r2 MCP-048=$r3" > "$ROOT/exits.txt"
(( r1 == 0 && r2 == 0 && r3 == 0 ))
