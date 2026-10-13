#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
R="$S/round3-mcp-live-readonly.json"
cat > "$R" <<'JSON'
[
  {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
  {"method":"notifications/initialized","params":{}},
  {"method":"tools/list","params":{},"_save":"tools-list.json"},
  {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{}},"_save":"screenshot-base64.json"},
  {"method":"tools/call","params":{"name":"grantiva_screenshot","arguments":{"format":"file"}},"_save":"screenshot-file.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"a11y-tree.json"},
  {"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}},"_save":"a11y-check.json"},
  {"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_save":"resource-hierarchy.json"},
  {"method":"resources/read","params":{"uri":"grantiva://screenshot"},"_save":"resource-screenshot.json"},
  {"method":"tools/call","params":{"name":"grantiva_test","arguments":{}},"_save":"test-android.json"},
  {"method":"tools/call","params":{"name":"grantiva_emulator_list","arguments":{}},"_save":"emulator-list.json"},
  {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{}},"_save":"tap-missing.json"},
  {"method":"tools/call","params":{"name":"grantiva_type","arguments":{}},"_save":"type-missing.json"},
  {"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{}},"_save":"swipe-missing.json"},
  {"method":"tools/call","params":{"name":"grantiva_script","arguments":{}},"_save":"script-missing.json"},
  {"method":"tools/call","params":{"name":"grantiva_emulator_ensure","arguments":{}},"_save":"ensure-missing.json"},
  {"method":"tools/call","params":{"name":"not_a_tool","arguments":{}},"_save":"unknown-tool.json"},
  {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context-after-errors.json"}
]
JSON

d="$E/MCP-live-readonly"; mkdir -p "$d/input"; cp "$R" "$d/input/requests.json"
rec MCP-live-readonly "$GRANTIVA runner start --detach --device emulator-5554; echo start-exit=\$?; cat .grantiva/session.json; adb forward --list"
ready=0
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  rd="$E/MCP-live-readonly/readiness"; mkdir -p "$rd"
  "$GRANTIVA" runner dump-hierarchy --format tree > "$rd/$attempt.out" 2> "$rd/$attempt.err"; rc=$?
  echo "attempt=$attempt rc=$rc" >> "$rd/attempts.txt"
  if [ "$rc" -eq 0 ]; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "runner never became hierarchy-ready" >> "$E/MCP-live-readonly/commands.txt"
  "$GRANTIVA" runner stop --json > "$E/MCP-live-readonly/readiness/stop.out" 2> "$E/MCP-live-readonly/readiness/stop.err"
  exit 1
fi
printf '# cwd=%s\n$ python3 -I %s %s %s %s -- %s mcp --project-dir %s --platform android\n' "$P" "$S/tools/client.py" "$R" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$E/MCP-live-readonly/commands.txt"
python3 -I "$S/tools/client.py" "$R" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
cp "$d/mcp/transcript.txt" "$d/transcript.txt"
rec MCP-live-readonly "$GRANTIVA runner stop --json; echo stop-exit=\$?; test ! -e .grantiva/session.json; echo no-session-exit=\$?; adb forward --list"
