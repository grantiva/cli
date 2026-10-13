#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"

run_session() {
  local id="$1" flow="$2" needle="$3" request_file="$4"
  local d="$E/$id"
  mkdir -p "$d/input" "$d/readiness" "$d/mcp"
  cp "$flow" "$d/input/"
  cp "$request_file" "$d/input/requests.json"
  printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --keep-alive --flow %s --report-dir %s\n' "$P" "$GRANTIVA" "$flow" "$d/report" > "$d/commands.txt"
  "$GRANTIVA" run --device emulator-5554 --no-build --keep-alive --flow "$flow" --report-dir "$d/report" > "$d/keepalive.out" 2> "$d/keepalive.err" &
  local kp=$! ready=0 attempt rc
  for attempt in $(seq 1 30); do
    "$GRANTIVA" runner dump-hierarchy --format tree > "$d/readiness/$attempt.out" 2> "$d/readiness/$attempt.err"; rc=$?
    printf 'attempt=%s rc=%s\n' "$attempt" "$rc" >> "$d/readiness/attempts.txt"
    if [ "$rc" -eq 0 ] && grep -q "$needle" "$d/readiness/$attempt.out"; then ready=1; break; fi
    sleep 1
  done
  if [ "$ready" -ne 1 ]; then
    "$GRANTIVA" runner stop --json > "$d/readiness/stop.out" 2> "$d/readiness/stop.err"
    wait "$kp"; return 1
  fi
  printf '$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$S/tools/client.py" "$d/input/requests.json" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
  python3 -I "$S/tools/client.py" "$d/input/requests.json" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
  cp "$d/mcp/transcript.txt" "$d/transcript.txt"
  "$GRANTIVA" runner stop --json > "$d/stop.out" 2> "$d/stop.err"; local src=$?
  wait "$kp"; local krc=$?
  printf '$ grantiva runner stop --json\nstop-rc=%s keepalive-rc=%s\n' "$src" "$krc" >> "$d/commands.txt"
  test ! -e .grantiva/session.json
}

tmp="$E/MCP-type-exact.requests.json"
cat > "$tmp" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Name"}},"_save":"tap-name.json"},
  {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":" Renamed"}},"_save":"type-renamed.json"},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"up"}},"_save":"swipe-up.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-final.json"}
]
JSON
run_session MCP-type-exact .maestro/coverage/19-park-edit.yaml 'Edit Landmark' "$tmp"

tmp="$E/MCP-script-exact.requests.json"
cat > "$tmp" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Gesture Lab"},{"wait":1},{"tap_xy":{"x":205,"y":457}},{"swipe":"up"}]}},"_save":"script-valid.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"type":"x"}]}},"_save":"script-no-focus-type.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"bogus":1},5]}},"_save":"script-invalid.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-final.json"}
]
JSON
run_session MCP-script-exact .maestro/coverage/20-park-deeplinks.yaml 'Gesture Lab' "$tmp"

rm -f "$E/MCP-type-exact.requests.json" "$E/MCP-script-exact.requests.json"
