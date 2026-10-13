#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/MCP074-D241-vrt-approve-errors-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project/.grantiva/captures/android" "$d/empty" "$d/mcp-approve" "$d/mcp-errors"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp-vrt-approve-errors-v1.sh" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
cp "$P/grantiva-android.yml" "$d/project/grantiva-android.yml"
cp "$E/AND-103-exact-rerun1/artifacts/Home.png" "$d/project/.grantiva/captures/android/Home.png"
cp "$E/AND-103-exact-rerun1/artifacts/Deep Links.png" "$d/project/.grantiva/captures/android/Deep Links.png"
cat > "$d/input/approve.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-vrt-approve","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{"screens":["Home"]}},"_save":"01-home.json"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{}},"_save":"02-all.json"}
]
JSON
cat > "$d/input/errors.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-vrt-errors","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}},"_save":"01-capture.json"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}},"_save":"02-compare.json"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{}},"_save":"03-approve.json"}
]
JSON
printf '# cwd=%s\n$ python3 -I client.py approve.json ... grantiva mcp --project-dir project --platform android\n# cwd=%s\n$ python3 -I client.py errors.json ... grantiva mcp --project-dir empty --platform android\n' "$d/project" "$d/empty" > "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/approve.json" "$d/mcp-approve" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android
arc=$?
find "$d/project/.grantiva/baselines/android" -maxdepth 1 -type f -print | sort > "$d/baselines.txt"
python3 -I "$d/input/client.py" "$d/input/errors.json" "$d/mcp-errors" "$d/empty" -- "$GRANTIVA" mcp --project-dir "$d/empty" --platform android
erc=$?
printf 'approve-client=%s errors-client=%s\n' "$arc" "$erc" > "$d/summary.txt"
test "$arc" -eq 0 && test "$erc" -eq 0
