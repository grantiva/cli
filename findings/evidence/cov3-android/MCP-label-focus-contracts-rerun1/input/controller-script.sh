#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/MCP-label-focus-contracts-rerun1"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-mcp-label-focus-contracts-v1.sh" "$base/input/controller-script.sh"
serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3
  [ -z "$serial" ] || exit 4
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6

cat > "$base/input/home.yaml" <<'EOF'
appId: com.kylebrowning.landmarks
---
- launchApp
- assertVisible: "Featured"
EOF
cp .maestro/coverage/19-park-edit.yaml "$base/input/19-park-edit.yaml"
cat > "$base/input/home-requests.json" <<'EOF'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"x"}},"_save":"type-no-focus.json"},
 {"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Landmarks"},{"type":"x"}]}},"_save":"script-step2-no-focus.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}},"_save":"tap-text-favorites.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-after.json"}
]
EOF
cat > "$base/input/edit-requests.json" <<'EOF'
[
 {"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"round3-coverage","version":"1"}}},
 {"method":"notifications/initialized","params":{}},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"heart"}},"_save":"tap-content-description-heart.json"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Name"}},"_save":"tap-placeholder-name.json"},
 {"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":" Exact"}},"_save":"type-after-placeholder.json"},
 {"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"_save":"tree-after.json"}
]
EOF

run_session() {
  name="$1"; flow="$2"; needle="$3"; requests="$4"; d="$base/$name"
  mkdir -p "$d/readiness" "$d/mcp"
  printf '# cwd=%s\n$ %q run --device %q --no-build --keep-alive --flow %q --report-dir %q\n' "$PWD" "$GRANTIVA" "$serial" "$flow" "$d/report" > "$d/commands.txt"
  "$GRANTIVA" run --device "$serial" --no-build --keep-alive --flow "$flow" --report-dir "$d/report" > "$d/keepalive.out" 2> "$d/keepalive.err" &
  kp=$!
  ready=0
  for attempt in $(seq 1 30); do
    "$GRANTIVA" runner dump-hierarchy --format tree > "$d/readiness/$attempt.out" 2> "$d/readiness/$attempt.err"
    rrc=$?
    printf 'attempt=%s rc=%s\n' "$attempt" "$rrc" >> "$d/readiness/attempts.txt"
    if [ "$rrc" -eq 0 ] && grep -q "$needle" "$d/readiness/$attempt.out"; then ready=1; break; fi
    sleep 1
  done
  if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$d/early-stop.out" 2> "$d/early-stop.err"; wait "$kp"; return 1; fi
  printf '$ python3 -I %q %q %q %q -- %q mcp --project-dir %q --platform android\n' "$S/tools/client.py" "$requests" "$d/mcp" "$P" "$GRANTIVA" "$P" >> "$d/commands.txt"
  python3 -I "$S/tools/client.py" "$requests" "$d/mcp" "$P" -- "$GRANTIVA" mcp --project-dir "$P" --platform android
  mrc=$?
  "$GRANTIVA" runner stop --json > "$d/stop.out" 2> "$d/stop.err"
  src=$?
  wait "$kp"
  krc=$?
  printf 'mcp-rc=%s stop-rc=%s keepalive-rc=%s\n' "$mrc" "$src" "$krc" >> "$d/commands.txt"
  [ "$mrc" -eq 0 ] && [ "$src" -eq 0 ] && test ! -e .grantiva/session.json
}
failures=0
run_session home "$base/input/home.yaml" Featured "$base/input/home-requests.json" || failures=$((failures+1))
run_session edit "$base/input/19-park-edit.yaml" 'Edit Landmark' "$base/input/edit-requests.json" || failures=$((failures+1))
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
