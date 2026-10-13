#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/MCP-killed-app-errors"; mkdir -p "$d/input" "$d/readiness" "$d/live" "$d/killed"
cp .maestro/coverage/20-park-deeplinks.yaml "$d/input/"

cat > "$d/input/live-requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"x"}},"_save":"type-no-focus.json"},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"round3-definitely-missing-label"}},"_save":"tap-missing-label.json"}
]
JSON
cat > "$d/input/killed-requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{}},"_save":"screenshot.json"},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}},"_save":"tap.json"},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"up"}},"_save":"swipe.json"},
  {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"x"}},"_save":"type.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"a11y-tree.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_save":"a11y-check.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Gesture Lab"}]}},"_save":"script.json"}
]
JSON

printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --keep-alive --flow .maestro/coverage/20-park-deeplinks.yaml --report-dir %s\n' "$P" "$GRANTIVA" "$d/report" > "$d/commands.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --keep-alive --flow .maestro/coverage/20-park-deeplinks.yaml --report-dir "$d/report" > "$d/keepalive.out" 2> "$d/keepalive.err" & kp=$!
ready=0
for attempt in $(seq 1 30); do
  "$GRANTIVA" runner dump-hierarchy --format tree > "$d/readiness/$attempt.out" 2> "$d/readiness/$attempt.err"; rc=$?
  printf 'attempt=%s rc=%s\n' "$attempt" "$rc" >> "$d/readiness/attempts.txt"
  if [ "$rc" -eq 0 ] && grep -q 'Gesture Lab' "$d/readiness/$attempt.out"; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$d/early-stop.out" 2> "$d/early-stop.err"; wait "$kp"; exit 1; fi

printf '$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$S/tools/client.py" "$d/input/live-requests.json" "$d/live" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
python3 -I "$S/tools/client.py" "$d/input/live-requests.json" "$d/live" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android

printf '$ adb -s emulator-5554 shell am force-stop com.kylebrowning.landmarks\n' >> "$d/commands.txt"
adb -s emulator-5554 shell am force-stop com.kylebrowning.landmarks > "$d/force-stop.out" 2> "$d/force-stop.err"; frc=$?
printf 'force-stop-rc=%s\n' "$frc" >> "$d/commands.txt"
adb -s emulator-5554 shell pidof com.kylebrowning.landmarks > "$d/pid-after-stop.out" 2> "$d/pid-after-stop.err"; prc=$?
printf '$ adb -s emulator-5554 shell pidof com.kylebrowning.landmarks\npidof-rc=%s\n' "$prc" >> "$d/commands.txt"

printf '$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$S/tools/client.py" "$d/input/killed-requests.json" "$d/killed" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
python3 -I "$S/tools/client.py" "$d/input/killed-requests.json" "$d/killed" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android

"$GRANTIVA" runner stop --json > "$d/stop.out" 2> "$d/stop.err"; src=$?
wait "$kp"; krc=$?
printf '$ grantiva runner stop --json\nstop-rc=%s keepalive-rc=%s\n' "$src" "$krc" >> "$d/commands.txt"
test ! -e .grantiva/session.json
