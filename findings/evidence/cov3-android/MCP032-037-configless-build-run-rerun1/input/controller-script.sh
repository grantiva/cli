#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/MCP032-037-configless-build-run-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project" "$d/build/mcp" "$d/run/mcp"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp032-037-configless-build-run-v1.sh" "$d/input/controller-script.sh"
cp "$S/tools/client.py" "$d/input/client.py"
# A real Gradle project copy with the Grantiva config deliberately excluded.
rsync -a --exclude grantiva-android.yml --exclude .gradle --exclude build --exclude '*.iml' "$P/" "$d/project/"
[ -x "$d/project/gradlew" ] || exit 3
[ ! -e "$d/project/grantiva-android.yml" ] || exit 4
cat > "$d/input/build.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-configless-build","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_build","arguments":{"module":"app","variant":"freeDebug"}},"_save":"build.json"}
]
JSON
cat > "$d/input/run.json" <<'JSON'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-configless-run","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_run","arguments":{"module":"app","variant":"freeDebug"}},"_save":"run.json"}
]
JSON
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 5
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 6; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 7
"$adb_bin" devices -l > "$d/adb-before-build.txt"
load="$(python3 -I -c 'import os; print(os.getloadavg()[0])')"
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 20 else 1)' "$load" || { echo "one-minute load $load is not below 20" >&2; exit 8; }
printf '# candidate=%s\n# cwd=%s (no grantiva-android.yml)\n# one-minute-load-before-build=%s\n$ python3 -I client.py build.json build/mcp project -- grantiva mcp --project-dir project --platform android\n' "$GRANTIVA" "$d/project" "$load" > "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/build.json" "$d/build/mcp" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android; brc=$?
python3 -I - "$d/build/mcp/build.json" "$d/build/text.txt" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))['result']; t='\n'.join(c.get('text','') for c in r.get('content',[])); open(sys.argv[2],'w').write(t+'\n'); assert not r.get('isError',False)
PY
bjsonrc=$?
"$adb_bin" devices -l > "$d/adb-after-build.txt"; cmp "$d/adb-before-build.txt" "$d/adb-after-build.txt" > "$d/build/adb-unchanged.txt" 2>&1; adbrc=$?
load2="$(python3 -I -c 'import os; print(os.getloadavg()[0])')"
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 20 else 1)' "$load2" || { echo "one-minute load $load2 is not below 20" >&2; exit 9; }
printf '\n# one-minute-load-before-run=%s\n$ python3 -I client.py run.json run/mcp project -- grantiva mcp --project-dir project --platform android\n' "$load2" >> "$d/commands.txt"
python3 -I "$d/input/client.py" "$d/input/run.json" "$d/run/mcp" "$d/project" -- "$GRANTIVA" mcp --project-dir "$d/project" --platform android; rrc=$?
python3 -I - "$d/run/mcp/run.json" "$d/run/text.txt" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))['result']; t='\n'.join(c.get('text','') for c in r.get('content',[])); open(sys.argv[2],'w').write(t+'\n'); assert not r.get('isError',False)
PY
rjsonrc=$?
"$adb_bin" devices -l > "$d/adb-after-run.txt"
printf 'buildClient=%s buildJSON=%s buildAdbUnchanged=%s runClient=%s runJSON=%s serial=%s\n' "$brc" "$bjsonrc" "$adbrc" "$rrc" "$rjsonrc" "$serial" > "$d/summary.txt"
test "$brc" -eq 0 && test "$bjsonrc" -eq 0 && test "$adbrc" -eq 0 && test "$rrc" -eq 0 && test "$rjsonrc" -eq 0
