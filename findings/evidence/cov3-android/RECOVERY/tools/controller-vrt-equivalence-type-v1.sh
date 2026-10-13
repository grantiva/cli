#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/MCP064-066-B2K55-D241-vrt-equivalence-type-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project" "$d/cli" "$d/mcp-no-session" "$d/mcp-live" "$d/mcp-type" "$d/readiness"
script="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-vrt-equivalence-type-v1.sh"
cp "$script" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
cp "$P/grantiva-android.yml" "$d/input/grantiva-android-five-screens.yml"
cp "$d/input/grantiva-android-five-screens.yml" "$d/project/grantiva-android.yml"
cat > "$d/input/park-list.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- assertVisible: "Golden Gate Bridge"
YAML
cat > "$d/input/grantiva-android-unfocused-type.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
screens:
  - name: Unfocused Type
    path:
      - type: "round3"
YAML
cat > "$d/input/capture.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-vrt-capture","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"capture.json"}
]
JSON
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"
[ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
[ "$avd" = cov3-android ] || { echo "owned AVD mismatch: $avd" >&2; exit 5; }
cd "$d/project"
printf '# cwd=%s\n$ %s diff capture --platform android --device %s --no-build --json\n' "$d/project" "$GRANTIVA" "$serial" > "$d/commands.txt"
"$GRANTIVA" diff capture --platform android --device "$serial" --no-build --json > "$d/cli/capture.json" 2> "$d/cli/capture.err"; clirc=$?
[ "$clirc" -eq 0 ] || exit 6
cp -R "$d/project/.grantiva/captures/android" "$d/cli/captures"
rm -rf "$d/project/.grantiva/captures/android"
printf '$ python3 -I client.py capture.json mcp-no-session project -- grantiva mcp --project-dir project --platform android\n' >> "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/capture.json" "$d/mcp-no-session" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android
nrc=$?
[ "$nrc" -eq 0 ] || exit 7
cp -R "$d/project/.grantiva/captures/android" "$d/mcp-no-session/captures"
rm -rf "$d/project/.grantiva/captures/android"
printf '$ %s run --platform android --device %s --no-build --keep-alive --flow %s --report-dir %s\n' "$GRANTIVA" "$serial" "$d/input/park-list.yaml" "$d/report" >> "$d/commands.txt"
"$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow "$d/input/park-list.yaml" --report-dir "$d/report" > "$d/run.out" 2> "$d/run.err" & runpid=$!
cleanup() { "$GRANTIVA" runner stop --json > "$d/trap-stop.json" 2> "$d/trap-stop.err" || true; wait "$runpid" 2>/dev/null || true; }
trap cleanup EXIT
ready=0
for attempt in $(seq 1 30); do
 if ! kill -0 "$runpid" 2>/dev/null; then echo "keepalive owner exited before readiness" >&2; exit 8; fi
 "$GRANTIVA" hierarchy --udid "$serial" --format json > "$d/readiness/$attempt.json" 2> "$d/readiness/$attempt.err"; rc=$?
 printf 'attempt=%s rc=%s golden=%s\n' "$attempt" "$rc" "$(grep -c 'Golden Gate Bridge' "$d/readiness/$attempt.json")" >> "$d/readiness/summary.txt"
 if [ "$rc" -eq 0 ] && grep -q 'Golden Gate Bridge' "$d/readiness/$attempt.json"; then ready=1; break; fi
 sleep 1
done
[ "$ready" -eq 1 ] || exit 9
printf '$ python3 -I client.py capture.json mcp-live project -- grantiva mcp --project-dir project --platform android\n' >> "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/capture.json" "$d/mcp-live" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android
lrc=$?
[ "$lrc" -eq 0 ] || exit 10
cp -R "$d/project/.grantiva/captures/android" "$d/mcp-live/captures"
cp "$d/input/grantiva-android-unfocused-type.yml" "$d/project/grantiva-android.yml"
printf '$ cp unfocused-type.yml project/grantiva-android.yml\n$ python3 -I client.py capture.json mcp-type project -- grantiva mcp --project-dir project --platform android\n' >> "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/capture.json" "$d/mcp-type" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android
trc=$?
cp "$d/input/grantiva-android-five-screens.yml" "$d/project/grantiva-android.yml"
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; stoprc=$?
wait "$runpid"; runrc=$?
trap - EXIT
printf 'cli=%s mcp-no-session=%s mcp-live=%s mcp-type=%s stop=%s run=%s\n' "$clirc" "$nrc" "$lrc" "$trc" "$stoprc" "$runrc" > "$d/summary.txt"
test "$trc" -eq 0 && test "$stoprc" -eq 0 && test "$runrc" -eq 0 && test ! -e "$d/project/.grantiva/session.json"
