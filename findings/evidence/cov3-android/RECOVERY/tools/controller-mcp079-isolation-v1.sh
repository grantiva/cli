#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/MCP-079-project-platform-tool-isolation-rerun1"; serial=emulator-5554
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/owner/.maestro" "$base/other" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp079-isolation-v1.sh" "$base/input/controller-script.sh"; cp "$W/findings/evidence/cov3-android/RECOVERY/tools/mcp079-isolation-client-v1.py" "$base/input/controller.py"; cp "$S/tools/client.py" "$base/input/mcp-client.py"
cp "$P/grantiva-android.yml" "$base/owner/grantiva-android.yml"; cp "$P/grantiva-android.yml" "$base/other/grantiva-android.yml"; cp "$P/.maestro/01-browse.yaml" "$base/owner/.maestro/01-browse.yaml"
cat > "$base/input/request.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-mcp079","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree.json"}
]
JSON
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
python3 -I "$base/input/controller.py" "$base/run" "$base/owner" "$base/other" "$GRANTIVA" "$serial" "$base/input/mcp-client.py" "$base/input/request.json"
