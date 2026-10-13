#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/B3-L10-failing-summary-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project/.maestro/coverage" "$d/shared-report" "$d/plain" "$d/quiet" "$d/json" "$d/preflow"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3-l10-failing-summary-v2.sh" "$d/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$d/input/grantiva-android.yml"
cp "$P/.maestro/coverage/02-exact-negative.yaml" "$d/input/02-exact-negative.yaml"
awk 'BEGIN{drop=0} /^flows:/{drop=1; print "flows:"; print "  - .maestro/01-browse.yaml"; next} /^diff:/{drop=0} !drop{print}' "$d/input/grantiva-android.yml" > "$d/input/single-flow.grantiva-android.yml"
cp "$d/input/single-flow.grantiva-android.yml" "$d/project/grantiva-android.yml"
cp "$d/input/02-exact-negative.yaml" "$d/project/.maestro/coverage/02-exact-negative.yaml"
cp "$d/input/02-exact-negative.yaml" "$d/project/.maestro/01-browse.yaml"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
cd "$d/project"; [ ! -e .grantiva/session.json ] || exit 6
: > "$d/commands.txt"
run_case() {
 name="$1"; shift
 printf '# cwd=%s\n$' "$d/project" >> "$d/commands.txt"; printf ' %q' "$@" >> "$d/commands.txt"; printf '\n' >> "$d/commands.txt"
 "$@" > "$d/$name/stdout.txt" 2> "$d/$name/stderr.txt"; rc=$?
 printf '%s\n' "$rc" > "$d/$name/exit.txt"; printf 'rc=%s\n\n' "$rc" >> "$d/commands.txt"
}
run_case plain "$GRANTIVA" run --platform android --device "$serial" --no-build --report-dir "$d/shared-report"
cp -R "$d/shared-report" "$d/plain/report"
rm -rf "$d/shared-report"; mkdir -p "$d/shared-report"
run_case quiet "$GRANTIVA" run --platform android --device "$serial" --no-build --quiet --report-dir "$d/shared-report"
cp -R "$d/shared-report" "$d/quiet/report"
rm -rf "$d/shared-report"; mkdir -p "$d/shared-report"
run_case json "$GRANTIVA" run --platform android --device "$serial" --no-build --json --report-dir "$d/shared-report"
cp -R "$d/shared-report" "$d/json/report"
run_case preflow "$GRANTIVA" run --platform android --device emulator-9999 --no-build
failures=0
for n in plain quiet json preflow; do [ "$(cat "$d/$n/exit.txt")" -ne 0 ] || failures=$((failures+1)); done
cmp "$d/plain/stdout.txt" "$d/quiet/stdout.txt" > "$d/plain-quiet-cmp.txt" 2>&1; cmprc=$?
[ "$cmprc" -eq 0 ] || failures=$((failures+1))
grep -F '✗ assertVisible: text="Golden Gate.*", exact=true' "$d/plain/stdout.txt" > "$d/failing-step.txt" || failures=$((failures+1))
grep -E '^  Screens: 5 total, [0-9]+ captured, [0-9]+ failed$' "$d/plain/stdout.txt" > "$d/screens-summary.txt" || failures=$((failures+1))
grep -E '^  Flows: [0-9]+ total, [0-9]+ passed, [0-9]+ failed(, [0-9]+ skipped)?$' "$d/plain/stdout.txt" > "$d/flows-summary.txt" || failures=$((failures+1))
jq -e '.allPassed == false and (.screens|length) > 0 and (.error|type)=="string"' "$d/json/stdout.txt" > "$d/json/assertion.txt" || failures=$((failures+1))
if grep -Eq '^Screens:|^Flows:' "$d/preflow/stdout.txt"; then failures=$((failures+1)); fi
printf 'cases=4 failures=%s plainQuietCmp=%s preflowNoSummary=1\n' "$failures" "$cmprc" > "$d/summary.txt"
test "$failures" -eq 0
