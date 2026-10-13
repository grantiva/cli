#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/D2-36-content-description-rerun1"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/readiness" "$base/mcp"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-d236-content-description-v1.sh" "$base/input/controller-script.sh"; cp "$S/tools/client.py" "$base/input/client.py"; cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 5
cat > "$base/input/requests.json" <<'EOF'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-before.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorite"}},"_save":"tap-content-description-favorite.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-after.json"}
]
EOF
cd "$P" || exit 6
printf '# cwd=%s\n$ %q run --device %q --no-build --keep-alive --flow .maestro/01-browse.yaml --report-dir %q\n' "$PWD" "$GRANTIVA" "$serial" "$base/report" > "$base/commands.txt"
"$GRANTIVA" run --device "$serial" --no-build --keep-alive --flow .maestro/01-browse.yaml --report-dir "$base/report" > "$base/keepalive.out" 2> "$base/keepalive.err" & kp=$!
ready=0; for attempt in $(seq 1 30); do "$GRANTIVA" runner dump-hierarchy --format tree > "$base/readiness/$attempt.out" 2> "$base/readiness/$attempt.err"; rc=$?; echo "attempt=$attempt rc=$rc" >> "$base/readiness/attempts.txt"; if [ "$rc" -eq 0 ] && grep -q 'Plan Visit' "$base/readiness/$attempt.out" && grep -q 'Favorite' "$base/readiness/$attempt.out"; then ready=1; break; fi; sleep 1; done
if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$base/early-stop.out" 2> "$base/early-stop.err"; wait "$kp"; exit 7; fi
python3 -I "$base/input/client.py" "$base/input/requests.json" "$base/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android; mrc=$?
"$GRANTIVA" runner stop --json > "$base/stop.out" 2> "$base/stop.err"; src=$?; wait "$kp"; krc=$?
printf 'mcp=%s stop=%s keepalive=%s\n' "$mrc" "$src" "$krc" > "$base/summary.txt"
[ "$mrc" -eq 0 ] && [ "$src" -eq 0 ] && test ! -e .grantiva/session.json
