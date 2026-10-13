#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/S2-01-inputtext-three-runs-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-s2-01-inputtext-three-runs-v1.sh" "$d/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$d/input/grantiva-android.yml"
cp "$P/.maestro/03-edit.yaml" "$d/input/03-edit.yaml"
cp "$d/input/grantiva-android.yml" "$d/project/grantiva-android.yml"
cp "$d/input/03-edit.yaml" "$d/project/.maestro/03-edit.yaml"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
[ ! -e "$d/project/.grantiva/session.json" ] || exit 6
"$adb_bin" -s "$serial" shell getprop hw.gpu.enabled > "$d/hw.gpu.enabled.txt"
: > "$d/commands.txt"; failures=0
cd "$d/project"
for i in 1 2 3; do
  r="$d/run-$i"; mkdir -p "$r/report"
  load="$(python3 -I -c 'import os; print(os.getloadavg()[0])')"
  printf '# run=%s one-minute-load=%s hw.gpu.enabled=%s\n$ %q run --platform android --device %q --no-build --flow .maestro/03-edit.yaml --report-dir %q\n' "$i" "$load" "$(cat "$d/hw.gpu.enabled.txt")" "$GRANTIVA" "$serial" "$r/report" >> "$d/commands.txt"
  t0="$(python3 -I -c 'import time; print(time.monotonic())')"
  "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/03-edit.yaml --report-dir "$r/report" > "$r/stdout.txt" 2> "$r/stderr.txt"; rc=$?
  elapsed="$(python3 -I -c 'import sys,time; print(round(time.monotonic()-float(sys.argv[1]),3))' "$t0")"
  printf '%s\n' "$rc" > "$r/exit.txt"; printf '%s\n' "$elapsed" > "$r/elapsed.txt"
  jq -e '([.commands[] | select(.type=="inputText" and .status=="passed")]|length)>=1 and ([.commands[].status]|all(.=="passed"))' "$r/report/flows/flow-000.json" > "$r/report-assertion.txt" || failures=$((failures+1))
  grep -F 'inputText' "$r/stderr.txt" > "$r/inputtext-live-lines.txt" || failures=$((failures+1))
  [ "$rc" -eq 0 ] || failures=$((failures+1))
  printf 'rc=%s elapsed=%s\n\n' "$rc" "$elapsed" >> "$d/commands.txt"
done
printf 'runs=3 failures=%s gpu=%s\n' "$failures" "$(cat "$d/hw.gpu.enabled.txt")" > "$d/summary.txt"
test "$failures" -eq 0
