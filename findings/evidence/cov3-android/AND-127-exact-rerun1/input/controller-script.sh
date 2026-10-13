#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/AND-127-exact-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/prelaunch-report" "$d/mcp"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and127-confirmed-app.sh"; cp "$script_path" "$d/input/controller-script.sh"
cp .maestro/01-browse.yaml "$d/input/"
cat > "$d/input/tools-list.requests.json" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/list","params":{},"_save":"tools-list.json"}
]
JSON
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml --report-dir %s\n' "$P" "$GRANTIVA" "$d/prelaunch-report" > "$d/commands.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml --report-dir "$d/prelaunch-report" > "$d/prelaunch.out" 2> "$d/prelaunch.err"; prc=$?
printf 'prelaunch-rc=%s\n$ %s runner start --device emulator-5554 --detach\n' "$prc" "$GRANTIVA" >> "$d/commands.txt"
"$GRANTIVA" runner start --device emulator-5554 --detach > "$d/start.out" 2> "$d/start.err"; src=$?
printf 'start-rc=%s\n' "$src" >> "$d/commands.txt"
cp .grantiva/session.json "$d/session.json"
"$GRANTIVA" runner dump-hierarchy --format tree > "$d/tree.out" 2> "$d/tree.err"; hrc=$?
printf '$ %s runner dump-hierarchy --format tree\nhierarchy-rc=%s\n' "$GRANTIVA" "$hrc" >> "$d/commands.txt"
python3 -I "$S/tools/client.py" "$d/input/tools-list.requests.json" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
adb forward --list > "$d/forwards-during.txt"
"$GRANTIVA" runner stop > "$d/stop.out" 2> "$d/stop.err"; xrc=$?
printf '$ grantiva runner stop\nstop-rc=%s\n' "$xrc" >> "$d/commands.txt"
adb forward --list > "$d/forwards-after.txt"
test "$prc" -eq 0; test "$src" -eq 0; test "$hrc" -eq 0; test "$xrc" -eq 0
grep -q 'Landmarks' "$d/tree.out"
test "$(jq '.result.tools|length' "$d/mcp/tools-list.json")" -eq 22
test ! -e .grantiva/session.json
test ! -s "$d/forwards-after.txt"
