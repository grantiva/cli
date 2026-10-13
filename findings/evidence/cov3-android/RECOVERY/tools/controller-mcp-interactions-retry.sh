#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/MCP-interactions-retry"; mkdir -p "$d/input" "$d/readiness"
cp .maestro/coverage/20-park-deeplinks.yaml "$d/input/"
R="$d/input/requests.json"
cat > "$R" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{}},"_save":"screenshot-base64.json"},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{"format":"file"}},"_save":"screenshot-file.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-initial.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_save":"a11y-check.json"},
  {"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_save":"resource-hierarchy.json"},
  {"method":"resources/read","params":{"uri":"grantiva://screenshot"},"_save":"resource-screenshot.json"},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}},"_save":"tap-gesture-lab.json"},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"x":205,"y":457}},"_save":"tap-pad-dp.json"},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"left"}},"_save":"swipe-left.json"},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"sideways"}},"_save":"swipe-invalid.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap_xy":{"x":205,"y":457}},{"wait":1},{"swipe":"up"}]}},"_save":"script-valid.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"bogus":1},5]}},"_save":"script-invalid.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-final.json"}
]
JSON
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --keep-alive --flow .maestro/coverage/20-park-deeplinks.yaml --report-dir %s\n' "$P" "$GRANTIVA" "$d/report" > "$d/commands.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --keep-alive --flow .maestro/coverage/20-park-deeplinks.yaml --report-dir "$d/report" > "$d/keepalive.out" 2> "$d/keepalive.err" & kp=$!
ready=0
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  "$GRANTIVA" runner dump-hierarchy --format tree > "$d/readiness/$attempt.out" 2> "$d/readiness/$attempt.err"; rc=$?
  echo "attempt=$attempt rc=$rc" >> "$d/readiness/attempts.txt"
  if [ "$rc" -eq 0 ] && grep -q 'Gesture Lab' "$d/readiness/$attempt.out"; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$d/readiness/stop.out" 2> "$d/readiness/stop.err"; wait "$kp"; exit 1; fi
printf '$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$S/tools/client.py" "$R" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
python3 -I "$S/tools/client.py" "$R" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
cp "$d/mcp/transcript.txt" "$d/transcript.txt"
"$GRANTIVA" runner stop --json > "$d/stop.out" 2> "$d/stop.err"; src=$?
wait "$kp"; krc=$?
printf '$ grantiva runner stop --json\nstop-rc=%s keepalive-rc=%s\n' "$src" "$krc" >> "$d/commands.txt"
test ! -e .grantiva/session.json
