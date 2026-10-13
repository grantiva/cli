#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/B-C11.3-configless-tools-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/empty" "$d/mcp"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-bc11-configless-tools-v1.sh" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
cat > "$d/input/requests.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-configless-tools","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{}},"_save":"build.json"},
 {"method":"tools/call","params":{"name":"grantiva_run","arguments":{}},"_save":"run.json"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"vrt.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_list","arguments":{}},"_save":"list.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{"name":"cov3-android"}},"_save":"boot.json"}
]
JSON
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"; [ "$serial" = emulator-5554 ] || exit 4
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
"$adb_bin" devices -l > "$d/adb-before.txt"
printf '# cwd=%s (no grantiva config)\n$ python3 -I client.py requests.json mcp empty -- grantiva mcp --project-dir empty --platform android\n' "$d/empty" > "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/requests.json" "$d/mcp" "$d/empty" -- "$GRANTIVA" mcp --project-dir "$d/empty" --platform android; clientrc=$?
"$adb_bin" devices -l > "$d/adb-after.txt"; cmp "$d/adb-before.txt" "$d/adb-after.txt" > "$d/adb-unchanged.txt" 2>&1; adbrc=$?
failures=0
for n in build run vrt; do
  jq -e '.result.isError==true and ([.result.content[].text]|join("\n")|contains("grantiva-android.yml not found at"))' "$d/mcp/$n.json" > "$d/$n.assertion.txt" || failures=$((failures+1))
done
jq -e '.result.isError != true and ([.result.content[].text]|join("\n")|contains("cov3-android"))' "$d/mcp/list.json" > "$d/list.assertion.txt" || failures=$((failures+1))
jq -e '.result.isError != true and ([.result.content[].text]|join("\n")|contains("Emulator reused: cov3-android (emulator-5554), already running"))' "$d/mcp/boot.json" > "$d/boot.assertion.txt" || failures=$((failures+1))
printf 'client=%s adbUnchanged=%s failures=%s\n' "$clientrc" "$adbrc" "$failures" > "$d/summary.txt"
test "$clientrc" -eq 0 && test "$adbrc" -eq 0 && test "$failures" -eq 0
