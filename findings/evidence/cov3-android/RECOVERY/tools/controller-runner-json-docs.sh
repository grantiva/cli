#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/AND-126-127-exact-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/mcp"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-runner-json-docs.sh"; cp "$script_path" "$d/input/controller-script.sh"
cat > "$d/input/tools-list.requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/list","params":{},"_save":"tools-list.json"}
]
JSON
adb forward --list > "$d/forwards-before.txt"
printf '# cwd=%s\n$ %s runner start --device emulator-5554 --headless --detach --json\n' "$P" "$GRANTIVA" > "$d/commands.txt"
"$GRANTIVA" runner start --device emulator-5554 --headless --detach --json > "$d/start.json" 2> "$d/start.err"; src=$?
printf 'start-rc=%s\n' "$src" >> "$d/commands.txt"
cp .grantiva/session.json "$d/session-after-start.json"
printf '$ %s runner start --device emulator-5554 --headless --detach --json\n' "$GRANTIVA" >> "$d/commands.txt"
"$GRANTIVA" runner start --device emulator-5554 --headless --detach --json > "$d/already.json" 2> "$d/already.err"; arc=$?
printf 'already-rc=%s\n' "$arc" >> "$d/commands.txt"
printf '$ %s runner dump-hierarchy --format tree\n' "$GRANTIVA" >> "$d/commands.txt"
"$GRANTIVA" runner dump-hierarchy --format tree > "$d/tree.out" 2> "$d/tree.err"; hrc=$?
printf 'hierarchy-rc=%s\n' "$hrc" >> "$d/commands.txt"
printf '$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$S/tools/client.py" "$d/input/tools-list.requests.json" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
python3 -I "$S/tools/client.py" "$d/input/tools-list.requests.json" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
adb forward --list > "$d/forwards-during.txt"
printf '$ %s runner stop --json\n' "$GRANTIVA" >> "$d/commands.txt"
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; xrc=$?
printf 'stop-rc=%s\n' "$xrc" >> "$d/commands.txt"
adb forward --list > "$d/forwards-after.txt"
test "$src" -eq 0; test "$arc" -eq 0; test "$hrc" -eq 0; test "$xrc" -eq 0
test ! -e .grantiva/session.json
