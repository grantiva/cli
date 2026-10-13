#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
R="$S/round3-mcp-interactions.json"
cat > "$R" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Deep Links"}},"_save":"tap-deep-links.json"},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}},"_save":"tap-gesture-lab.json"},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"x":205,"y":457}},"_save":"tap-pad-dp.json"},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"left"}},"_save":"swipe-left.json"},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"sideways"}},"_save":"swipe-invalid.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap_xy":{"x":205,"y":457}},{"wait":1},{"swipe":"up"}]}},"_save":"script-valid.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"bogus":1},5]}},"_save":"script-invalid.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-final.json"}
]
JSON
d="$E/MCP-interactions"; mkdir -p "$d/input"; cp "$R" "$d/input/requests.json"
rec MCP-interactions "adb -s emulator-5554 shell pm clear com.kylebrowning.landmarks; adb -s emulator-5554 shell monkey -p com.kylebrowning.landmarks 1; sleep 2; $GRANTIVA runner start --detach --device emulator-5554; echo start-exit=\$?; cat .grantiva/session.json"
ready=0; rd="$d/readiness"; mkdir -p "$rd"
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  "$GRANTIVA" runner dump-hierarchy --format tree > "$rd/$attempt.out" 2> "$rd/$attempt.err"; rc=$?
  echo "attempt=$attempt rc=$rc" >> "$rd/attempts.txt"
  if [ "$rc" -eq 0 ]; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$rd/stop.out" 2> "$rd/stop.err"; exit 1; fi
printf '# cwd=%s\n$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$P" "$S/tools/client.py" "$R" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
python3 -I "$S/tools/client.py" "$R" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
cp "$d/mcp/transcript.txt" "$d/transcript.txt"
rec MCP-interactions "$GRANTIVA runner stop --json; echo stop-exit=\$?; test ! -e .grantiva/session.json; echo no-session-exit=\$?; adb forward --list"
