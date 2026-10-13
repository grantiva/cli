#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/D239-X011-MCP076-context-resources-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/readiness" "$d/mcp" "$d/source"
script="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-context-resources-list-v2.sh"
cp "$script" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"
[ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
[ "$avd" = cov3-android ] || { echo "owned AVD mismatch: $avd" >&2; exit 5; }
cat > "$d/input/requests.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-context-resources","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-tool.json"},
 {"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_save":"tree-resource.json"},
 {"method":"resources/read","params":{"uri":"grantiva://screenshot"},"_save":"screenshot-resource.json"}
]
JSON
printf '# cwd=%s\n$ %s runner start --platform android --device %s --application-id com.kylebrowning.landmarks --detach --json\n' "$P" "$GRANTIVA" "$serial" > "$d/commands.txt"
"$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json > "$d/start.json" 2> "$d/start.err"; startrc=$?
[ "$startrc" -eq 0 ] || exit 6
cleanup() { "$GRANTIVA" runner stop --json > "$d/trap-stop.json" 2> "$d/trap-stop.err" || true; }
trap cleanup EXIT
ready=0
for attempt in $(seq 1 30); do
 "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format tree > "$d/readiness/$attempt.out" 2> "$d/readiness/$attempt.err"; rc=$?
 printf 'attempt=%s rc=%s landmarks=%s golden=%s\n' "$attempt" "$rc" "$(grep -c Landmarks "$d/readiness/$attempt.out")" "$(grep -c 'Golden Gate Bridge' "$d/readiness/$attempt.out")" >> "$d/readiness/summary.txt"
 if [ "$rc" -eq 0 ] && grep -q Landmarks "$d/readiness/$attempt.out" && grep -q 'Golden Gate Bridge' "$d/readiness/$attempt.out"; then ready=1; break; fi
 sleep 1
done
[ "$ready" -eq 1 ] || exit 7
printf '$ %s hierarchy --udid %s\n$ %s hierarchy --udid %s --format json\n' "$GRANTIVA" "$serial" "$GRANTIVA" "$serial" >> "$d/commands.txt"
"$GRANTIVA" hierarchy --udid "$serial" > "$d/hierarchy.xml" 2> "$d/hierarchy-xml.err"; xmlrc=$?
"$GRANTIVA" hierarchy --udid "$serial" --format json > "$d/hierarchy.json" 2> "$d/hierarchy-json.err"; jsonrc=$?
[ "$xmlrc" -eq 0 ] && [ "$jsonrc" -eq 0 ] || exit 8
printf '$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$d/input/client.py" "$d/input/requests.json" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/requests.json" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
clientrc=$?
cp "$W/../release-main/Tests/GrantivaMCPTests/ContextToolTests.swift" "$d/source/ContextToolTests.swift"
git -C "$W/../release-main" rev-parse HEAD > "$d/source/cli-head.txt"
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; stoprc=$?
trap - EXIT
printf 'start=%s hierarchy_xml=%s hierarchy_json=%s client=%s stop=%s\n' "$startrc" "$xmlrc" "$jsonrc" "$clientrc" "$stoprc" > "$d/summary.txt"
test "$clientrc" -eq 0 && test "$stoprc" -eq 0 && test ! -e .grantiva/session.json
