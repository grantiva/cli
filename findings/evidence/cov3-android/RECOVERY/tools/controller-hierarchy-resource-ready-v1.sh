#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/hierarchy-resource-ready-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/readiness" "$base/mcp"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-hierarchy-resource-ready-v1.sh" "$base/input/controller-script.sh"
cp "$S/tools/client.py" "$base/input/client.py"
serial=""
while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cat > "$base/input/home.yaml" <<'EOF'
appId: com.kylebrowning.landmarks
---
- launchApp
- assertVisible: "Featured"
EOF
cat > "$base/input/requests.json" <<'EOF'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_context","arguments":{}},"_save":"context.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"a11y-tree.json"},
 {"method":"resources/read","params":{"uri":"grantiva://hierarchy"},"_save":"resource-hierarchy.json"},
 {"method":"resources/read","params":{"uri":"grantiva://screenshot"},"_save":"resource-screenshot.json"}
]
EOF
cd "$P" || exit 6
printf '# cwd=%s\n$ %q run --device %q --no-build --keep-alive --flow %q --report-dir %q\n' "$PWD" "$GRANTIVA" "$serial" "$base/input/home.yaml" "$base/report" > "$base/commands.txt"
"$GRANTIVA" run --device "$serial" --no-build --keep-alive --flow "$base/input/home.yaml" --report-dir "$base/report" > "$base/keepalive.out" 2> "$base/keepalive.err" & kp=$!
ready=0
for attempt in $(seq 1 30); do "$GRANTIVA" runner dump-hierarchy --format tree > "$base/readiness/$attempt.out" 2> "$base/readiness/$attempt.err"; rc=$?; echo "attempt=$attempt rc=$rc" >> "$base/readiness/attempts.txt"; if [ "$rc" -eq 0 ] && grep -q Featured "$base/readiness/$attempt.out"; then ready=1; break; fi; sleep 1; done
if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$base/early-stop.out" 2> "$base/early-stop.err"; wait "$kp"; exit 7; fi
"$GRANTIVA" hierarchy --format json > "$base/hierarchy.json" 2> "$base/hierarchy.err"; hrc=$?
"$GRANTIVA" runner dump-hierarchy --format json > "$base/dump-hierarchy.json" 2> "$base/dump-hierarchy.err"; drc=$?
python3 -I "$base/input/client.py" "$base/input/requests.json" "$base/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android; mrc=$?
"$GRANTIVA" runner stop --json > "$base/stop.out" 2> "$base/stop.err"; src=$?
wait "$kp"; krc=$?
printf 'hierarchy=%s dump=%s mcp=%s stop=%s keepalive=%s\n' "$hrc" "$drc" "$mrc" "$src" "$krc" > "$base/summary.txt"
[ "$hrc" -eq 0 ] && [ "$drc" -eq 0 ] && [ "$mrc" -eq 0 ] && [ "$src" -eq 0 ] && test ! -e .grantiva/session.json
