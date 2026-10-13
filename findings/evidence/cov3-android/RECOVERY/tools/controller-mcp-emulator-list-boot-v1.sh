#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/MCP056-057-emulator-list-boot-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/empty" "$d/mcp-list" "$d/mcp-boot"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp-emulator-list-boot-v1.sh" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
cat > "$d/input/list.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-emulator-list","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_list","arguments":{}},"_save":"list.json"}
]
JSON
cat > "$d/input/boot.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-emulator-boot","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{"name":"cov3-android"}},"_save":"explicit.json"},
 {"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{}},"_save":"configured-default.json"}
]
JSON
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"
[ -x "$adb_bin" ] || exit 3
"$adb_bin" devices -l > "$d/adb-before.txt"
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
[ "$avd" = cov3-android ] || { echo "owned AVD mismatch: $avd" >&2; exit 5; }
printf '# cwd=%s\n$ python3 -I client.py list.json ... grantiva mcp --project-dir empty --platform android\n# cwd=%s\n$ python3 -I client.py boot.json ... grantiva mcp --project-dir project --platform android\n' "$d/empty" "$P" > "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/list.json" "$d/mcp-list" "$d/empty" -- "$GRANTIVA" mcp --project-dir "$d/empty" --platform android
lrc=$?
python3 -I "$d/input/client.py" "$d/input/boot.json" "$d/mcp-boot" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
brc=$?
"$adb_bin" devices -l > "$d/adb-after.txt"
post="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
printf 'list=%s boot=%s serial-before=%s serial-after=%s\n' "$lrc" "$brc" "$serial" "$post" > "$d/summary.txt"
test "$lrc" -eq 0 && test "$brc" -eq 0 && test "$post" = "$serial"
