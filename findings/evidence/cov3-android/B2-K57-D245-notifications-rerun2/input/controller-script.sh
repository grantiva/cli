#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"
if [ ! -x "$adb_bin" ]; then echo "adb executable missing: $adb_bin" >&2; exit 3; fi
d="$E/B2-K57-D245-notifications-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/readiness" "$d/mcp"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp-notification-contracts-v2.sh" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
cp .maestro/coverage/20-park-deeplinks.yaml "$d/input/20-park-deeplinks.yaml"
cat > "$d/input/requests.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-notifications","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such Element"}},"_save":"01-failed-before-subscribe.json"},
 {"method":"resources/subscribe","params":{"uri":"grantiva://hierarchy"},"_save":"02-subscribe.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}},"_save":"03-successful-tap.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{}},"_save":"04-rejected-tap.json"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Landmarks"},{"tap":"No Such Element"}]}},"_save":"05-partial-script.json"},
 {"method":"resources/unsubscribe","params":{"uri":"grantiva://hierarchy"},"_save":"06-unsubscribe.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}},"_save":"07-success-after-unsubscribe.json"},
 {"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_save":"08-final-tree.json"}
]
JSON
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
if [ "$serial" != "emulator-5554" ]; then echo "owned serial mismatch: $serial" >&2; exit 3; fi
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
if [ "$avd" != "cov3-android" ]; then echo "owned AVD mismatch: $avd" >&2; exit 4; fi
printf '# cwd=%s\n$ %s run --platform android --device %s --no-build --keep-alive --flow .maestro/coverage/20-park-deeplinks.yaml --report-dir %s\n' "$P" "$GRANTIVA" "$serial" "$d/report" > "$d/commands.txt"
"$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/coverage/20-park-deeplinks.yaml --report-dir "$d/report" > "$d/keepalive.out" 2> "$d/keepalive.err" & kp=$!
cleanup() { "$GRANTIVA" runner stop --json > "$d/trap-stop.json" 2> "$d/trap-stop.err" || true; wait "$kp" 2>/dev/null || true; }
trap cleanup EXIT
ready=0
for attempt in $(seq 1 30); do
 if ! kill -0 "$kp" 2>/dev/null; then echo "keepalive owner exited before readiness" >&2; exit 6; fi
 "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format tree > "$d/readiness/$attempt.out" 2> "$d/readiness/$attempt.err"; rc=$?
 printf 'attempt=%s rc=%s gesture=%s\n' "$attempt" "$rc" "$(grep -c 'Gesture Lab' "$d/readiness/$attempt.out")" >> "$d/readiness/summary.txt"
 if [ "$rc" -eq 0 ] && grep -q 'Gesture Lab' "$d/readiness/$attempt.out"; then ready=1; break; fi
 sleep 1
done
if [ "$ready" -ne 1 ]; then exit 5; fi
printf '$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$d/input/client.py" "$d/input/requests.json" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/requests.json" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
clientrc=$?
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; stoprc=$?
wait "$kp"; runrc=$?
trap - EXIT
printf 'client=%s stop=%s run=%s\n' "$clientrc" "$stoprc" "$runrc" > "$d/summary.txt"
test "$clientrc" -eq 0 && test "$stoprc" -eq 0 && test "$runrc" -eq 0 && test ! -e .grantiva/session.json
