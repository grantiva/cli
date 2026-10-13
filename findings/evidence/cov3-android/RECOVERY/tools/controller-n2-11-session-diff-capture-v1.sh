#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/N2-11-session-diff-capture-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project/.maestro/coverage/cfg" "$d/stock" "$d/unsupported" "$d/readiness"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-n2-11-session-diff-capture-v1.sh" "$d/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$d/input/stock.grantiva-android.yml"
cp "$P/.maestro/coverage/cfg/screens-steps.grantiva-android.yml" "$d/input/unsupported.grantiva-android.yml"
cp "$P/.maestro/coverage/cfg/relaunch.yaml" "$d/input/relaunch.yaml"
cp "$P/.maestro/coverage/14-runflow-sub.yaml" "$d/input/14-runflow-sub.yaml"
cp "$d/input/stock.grantiva-android.yml" "$d/project/grantiva-android.yml"
cp "$d/input/relaunch.yaml" "$d/project/.maestro/coverage/cfg/relaunch.yaml"
cp "$d/input/14-runflow-sub.yaml" "$d/project/.maestro/coverage/14-runflow-sub.yaml"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
cd "$d/project"; [ ! -e .grantiva/session.json ] || exit 6
printf '# cwd=%s\n$ %s runner start --platform android --device %s --application-id com.kylebrowning.landmarks --detach --json\n' "$d/project" "$GRANTIVA" "$serial" > "$d/commands.txt"
"$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json > "$d/start.json" 2> "$d/start.err"; src=$?
[ "$src" -eq 0 ] || exit 7
cleanup() { "$GRANTIVA" runner stop --json > "$d/trap-stop.json" 2> "$d/trap-stop.err" || true; }
trap cleanup EXIT
ready=0
for poll in $(seq 1 20); do
 "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json > "$d/readiness/$poll.json" 2> "$d/readiness/$poll.err"; hrc=$?
 if [ "$hrc" -eq 0 ] && grep -q 'Golden Gate Bridge' "$d/readiness/$poll.json"; then ready=1; break; fi
 sleep 0.25
done
[ "$ready" -eq 1 ] || exit 8
printf '\n$ %s diff capture --platform android --device %s --no-build --json\n' "$GRANTIVA" "$serial" >> "$d/commands.txt"
"$GRANTIVA" diff capture --platform android --device "$serial" --no-build --json > "$d/stock/capture.json" 2> "$d/stock/capture.err"; stockrc=$?
cp -R "$d/project/.grantiva/captures/android" "$d/stock/captures"
stockcount="$(find "$d/stock/captures" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
runner_pid="$(jq -r '.pid' "$d/start.json")"; kill -0 "$runner_pid" 2>/dev/null; alive_after_stock=$?
cp "$d/input/unsupported.grantiva-android.yml" "$d/project/grantiva-android.yml"
printf '\n# config swapped to exact frozen cfg/screens-steps\n$ %s diff capture --platform android --device %s --no-build --json\n' "$GRANTIVA" "$serial" >> "$d/commands.txt"
"$GRANTIVA" diff capture --platform android --device "$serial" --no-build --json > "$d/unsupported/capture.json" 2> "$d/unsupported/capture.err"; unsupportedrc=$?
grep -F 'grantiva runner stop' "$d/unsupported/capture.err" > "$d/unsupported/remedy.txt"; remedyrc=$?
kill -0 "$runner_pid" 2>/dev/null; alive_after_refusal=$?
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; stoprc=$?
trap - EXIT
printf 'start=%s ready=%s stock=%s stockPNGs=%s aliveAfterStock=%s unsupported=%s remedy=%s aliveAfterRefusal=%s stop=%s\n' "$src" "$ready" "$stockrc" "$stockcount" "$alive_after_stock" "$unsupportedrc" "$remedyrc" "$alive_after_refusal" "$stoprc" > "$d/summary.txt"
test "$stockrc" -eq 0 && test "$stockcount" -eq 5 && test "$alive_after_stock" -eq 0 && test "$unsupportedrc" -ne 0 && test "$remedyrc" -eq 0 && test "$alive_after_refusal" -eq 0 && test "$stoprc" -eq 0 && test ! -e .grantiva/session.json
