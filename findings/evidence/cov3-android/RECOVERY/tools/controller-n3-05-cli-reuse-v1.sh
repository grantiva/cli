#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/N3-05-cli-emulator-reuse-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-n3-05-cli-reuse-v1.sh" "$d/input/controller-script.sh"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"
[ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
[ "$avd" = cov3-android ] || { echo "owned AVD mismatch: $avd" >&2; exit 5; }
"$adb_bin" devices -l > "$d/adb-before.txt"
printf '# candidate=%s\n$ grantiva emulator ensure --name cov3-android\n' "$GRANTIVA" > "$d/commands.txt"
"$GRANTIVA" emulator ensure --name cov3-android > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?
"$adb_bin" devices -l > "$d/adb-after.txt"
cmp "$d/adb-before.txt" "$d/adb-after.txt" > "$d/adb-unchanged.txt" 2>&1; adbrc=$?
[ "$(cat "$d/stdout.txt")" = emulator-5554 ]; outrc=$?
grep -Fx 'Reused cov3-android (emulator-5554) — Booted' "$d/stderr.txt" > "$d/exact-stderr-line.txt"; errrc=$?
printf 'exit=%s adbUnchanged=%s exactStdout=%s exactStderr=%s serial=%s avd=%s\n' "$rc" "$adbrc" "$outrc" "$errrc" "$serial" "$avd" > "$d/summary.txt"
test "$rc" -eq 0 && test "$adbrc" -eq 0 && test "$outrc" -eq 0 && test "$errrc" -eq 0
