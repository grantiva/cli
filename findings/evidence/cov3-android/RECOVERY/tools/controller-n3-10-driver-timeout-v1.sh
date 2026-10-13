#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/N3-10-driver-start-timeout-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/with-env/report" "$base/without-env/report"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-n3-10-driver-timeout-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/grantiva-android.yml"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
cp "$base/input/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$base/input/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
cd "$base/project"; [ ! -e .grantiva/session.json ] || exit 6
printf '# cwd=%s\n$ GRANTIVA_DRIVER_START_TIMEOUT=45 %s run --platform android --device %s --no-build --flow .maestro/01-browse.yaml --verbose --report-dir %s\n' "$base/project" "$GRANTIVA" "$serial" "$base/with-env/report" > "$base/commands.txt"
GRANTIVA_DRIVER_START_TIMEOUT=45 "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml --verbose --report-dir "$base/with-env/report" > "$base/with-env/stdout.txt" 2> "$base/with-env/stderr.txt"; withrc=$?
printf 'rc=%s\n\n$ env -u GRANTIVA_DRIVER_START_TIMEOUT %s run --platform android --device %s --no-build --flow .maestro/01-browse.yaml --verbose --report-dir %s\n' "$withrc" "$GRANTIVA" "$serial" "$base/without-env/report" >> "$base/commands.txt"
env -u GRANTIVA_DRIVER_START_TIMEOUT "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml --verbose --report-dir "$base/without-env/report" > "$base/without-env/stdout.txt" 2> "$base/without-env/stderr.txt"; withoutrc=$?
printf 'rc=%s\n' "$withoutrc" >> "$base/commands.txt"
grep -F -- '--driver-start-timeout 45' "$base/with-env/stderr.txt" > "$base/with-env/runner-argv-match.txt" || exit 7
if grep -F -- '--driver-start-timeout 45' "$base/without-env/stderr.txt" > "$base/without-env/unexpected-timeout-match.txt"; then exit 8; fi
grep -E -- 'maestro-runner|grantiva-runner' "$base/with-env/stderr.txt" > "$base/with-env/runner-lines.txt" || true
grep -E -- 'maestro-runner|grantiva-runner' "$base/without-env/stderr.txt" > "$base/without-env/runner-lines.txt" || true
printf 'withEnv=%s withoutEnv=%s timeout45OnlyWithEnv=1\n' "$withrc" "$withoutrc" > "$base/summary.txt"
test "$withrc" -eq 0 && test "$withoutrc" -eq 0
