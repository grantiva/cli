#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/MCP-069-advanced-swipes-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input/configs" "$d/project" "$d/readiness"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp069-advanced-swipes-v2.sh" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
cat > "$d/input/request.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-mcp069-swipes","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"capture.json"}
]
JSON
cat > "$d/input/configs/from.yml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- swipe:
    direction: UP
    from: "Landmarks"
- takeScreenshot: "Swipe From"
YAML
cat > "$d/input/configs/points.yml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- swipe:
    start: "50%, 80%"
    end: "50%, 20%"
- takeScreenshot: "Swipe Points"
YAML
cat > "$d/input/configs/duration.yml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- swipe:
    direction: UP
    duration: 400
- takeScreenshot: "Swipe Duration"
YAML
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
cd "$d/project"; [ ! -e .grantiva/session.json ] || exit 6
cp "$d/input/configs/from.yml" grantiva-android.yml
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
failures=0
for name in from points duration; do
 cp "$d/input/configs/$name.yml" grantiva-android.yml
 mkdir -p "$d/$name/mcp"
 printf '\n# config=%s\n$ python3 -I client.py request.json %s/mcp project -- grantiva mcp --project-dir project --platform android\n' "$d/input/configs/$name.yml" "$d/$name" >> "$d/commands.txt"
 python3 -I "$d/input/client.py" "$d/input/request.json" "$d/$name/mcp" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android; mrc=$?
 printf '%s\n' "$mrc" > "$d/$name/mcp.exit.txt"
 python3 -I - "$d/$name/mcp/capture.json" "$d/$name/error-text.txt" "$name" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x.get('result',{}); t='\n'.join(c.get('text','') for c in r.get('content',[]))
open(sys.argv[2],'w').write(t+'\n')
expected={'from':'a swipe from an element','points':'a swipe between points','duration':'a swipe with a duration'}[sys.argv[3]]
assert r.get('isError') is True and expected in t and 'grantiva runner stop' in t
PY
 prc=$?
 if [ "$mrc" -ne 0 ] || [ "$prc" -ne 0 ]; then failures=$((failures+1)); fi
done
find "$d/project/.grantiva/captures" -type f -print 2>/dev/null | sort > "$d/captures-after.txt" || true
[ ! -s "$d/captures-after.txt" ] || failures=$((failures+1))
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; stoprc=$?
trap - EXIT
printf 'start=%s ready=%s variants=3 failures=%s captures=0 stop=%s\n' "$src" "$ready" "$failures" "$stoprc" > "$d/summary.txt"
test "$failures" -eq 0 && test "$stoprc" -eq 0 && test ! -e .grantiva/session.json
