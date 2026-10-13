#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/B2-K55-detached-vrt-equivalence-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project" "$d/mcp" "$d/readiness"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-vrt-detached-equivalence-v1.sh" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
cp "$P/grantiva-android.yml" "$d/input/grantiva-android.yml"
cp "$d/input/grantiva-android.yml" "$d/project/grantiva-android.yml"
cat > "$d/input/capture.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-vrt-detached","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"capture.json"}
]
JSON
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
cd "$d/project"; [ ! -e .grantiva/session.json ] || exit 6
printf '# cwd=%s\n$ %s runner start --platform android --device %s --application-id com.kylebrowning.landmarks --detach --json\n' "$d/project" "$GRANTIVA" "$serial" > "$d/commands.txt"
"$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json > "$d/start.json" 2> "$d/start.err"; src=$?
[ "$src" -eq 0 ] || exit 7
cleanup() { "$GRANTIVA" runner stop --json > "$d/trap-stop.json" 2> "$d/trap-stop.err" || true; }
trap cleanup EXIT
ready=0
for poll in $(seq 1 20); do
 "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json > "$d/readiness/$poll.json" 2> "$d/readiness/$poll.err"; hrc=$?
 if [ "$hrc" -eq 0 ] && grep -q 'Golden Gate Bridge' "$d/readiness/$poll.json"; then ready=1; break; fi
 sleep 0.25
done
[ "$ready" -eq 1 ] || exit 8
printf '$ python3 -I client.py capture.json mcp project -- grantiva mcp --project-dir project --platform android\n' >> "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/capture.json" "$d/mcp" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android
mrc=$?
[ "$mrc" -eq 0 ] || exit 9
cp -R "$d/project/.grantiva/captures/android" "$d/mcp/captures"
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; stoprc=$?
trap - EXIT
printf 'start=%s ready=%s mcp=%s stop=%s\n' "$src" "$ready" "$mrc" "$stoprc" > "$d/summary.txt"
test "$stoprc" -eq 0 && test ! -e .grantiva/session.json
