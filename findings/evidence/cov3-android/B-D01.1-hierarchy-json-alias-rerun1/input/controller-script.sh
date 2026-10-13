#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/B-D01.1-hierarchy-json-alias-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project/.maestro" "$d/readiness"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-bd01-hierarchy-json-alias-v1.sh" "$d/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$d/project/grantiva-android.yml"
cat > "$d/input/park.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- assertVisible: "Golden Gate Bridge"
YAML
cp "$d/input/park.yaml" "$d/project/.maestro/park.yaml"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
cd "$d/project"; [ ! -e .grantiva/session.json ] || exit 6
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --keep-alive --flow .maestro/park.yaml --report-dir %q\n' "$d/project" "$GRANTIVA" "$serial" "$d/report" > "$d/commands.txt"
"$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/park.yaml --report-dir "$d/report" > "$d/run.out" 2> "$d/run.err" & runpid=$!
cleanup() { "$GRANTIVA" runner stop --json > "$d/trap-stop.json" 2> "$d/trap-stop.err" || true; wait "$runpid" 2>/dev/null || true; }
trap cleanup EXIT
ready=0
for attempt in $(seq 1 30); do
  if ! kill -0 "$runpid" 2>/dev/null; then exit 7; fi
  "$GRANTIVA" hierarchy --udid "$serial" --format json > "$d/readiness/$attempt.json" 2> "$d/readiness/$attempt.err"; rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'Golden Gate Bridge' "$d/readiness/$attempt.json"; then ready=1; break; fi
  sleep 1
done
[ "$ready" -eq 1 ] || exit 8
run_case() {
  name="$1"; shift
  printf '$' >> "$d/commands.txt"; printf ' %q' "$@" >> "$d/commands.txt"; printf '\n' >> "$d/commands.txt"
  "$@" > "$d/$name.out" 2> "$d/$name.err"; rc=$?; printf '%s\n' "$rc" > "$d/$name.exit.txt"
}
run_case hierarchy-json "$GRANTIVA" hierarchy --udid "$serial" --json
run_case hierarchy-format "$GRANTIVA" hierarchy --udid "$serial" --format json
run_case dump-json "$GRANTIVA" runner dump-hierarchy --udid "$serial" --json
run_case dump-format "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json
run_case hierarchy-conflict "$GRANTIVA" hierarchy --udid "$serial" --json --format xml
run_case dump-conflict "$GRANTIVA" runner dump-hierarchy --udid "$serial" --json --format xml
failures=0
for n in hierarchy-json hierarchy-format dump-json dump-format; do [ "$(cat "$d/$n.exit.txt")" -eq 0 ] || failures=$((failures+1)); jq -e . "$d/$n.out" > "$d/$n.valid-json.txt" || failures=$((failures+1)); done
cmp "$d/hierarchy-json.out" "$d/hierarchy-format.out" > "$d/hierarchy-alias-cmp.txt" 2>&1 || failures=$((failures+1))
cmp "$d/dump-json.out" "$d/dump-format.out" > "$d/dump-alias-cmp.txt" 2>&1 || failures=$((failures+1))
for n in hierarchy-conflict dump-conflict; do [ "$(cat "$d/$n.exit.txt")" -eq 64 ] || failures=$((failures+1)); grep -F 'conflict; pass one.' "$d/$n.err" > "$d/$n.assertion.txt" || failures=$((failures+1)); done
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; stoprc=$?
wait "$runpid"; runrc=$?; trap - EXIT
printf 'failures=%s stop=%s run=%s\n' "$failures" "$stoprc" "$runrc" > "$d/summary.txt"
test "$failures" -eq 0 && test "$stoprc" -eq 0 && test "$runrc" -eq 0
