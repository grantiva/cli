#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K44-preflight-exact-rerun1"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/project/flow-directory" "$base/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k44-preflight-validation.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<Y
platform: android
application_id: com.kylebrowning.landmarks
emulator: cov3-android
flows:
  - configured-missing.yaml
Y
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 4
echo "$serial" > "$base/input/serial.txt"; adb devices -l > "$base/input/adb-before.txt"; adb forward --list > "$base/input/forwards-before.txt"
run(){ n=$1; shift; mkdir -p "$base/$n"; { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } > "$base/$n/commands.txt"; t0=$(python3 -I -c 'import time;print(time.time())'); "$@" >"$base/$n/stdout.log" 2>"$base/$n/stderr.log"; rc=$?; t1=$(python3 -I -c 'import time;print(time.time())'); python3 -I -c 'import sys;print(round(float(sys.argv[2])-float(sys.argv[1]),3))' "$t0" "$t1" > "$base/$n/elapsed.txt"; echo rc=$rc >> "$base/$n/commands.txt"; [ $rc -ne 0 ]; }
cd "$base/project"; failures=0
run missing-build "$GRANTIVA" run --device "$serial" --flow missing.yaml || failures=$((failures+1))
run missing-nobuild "$GRANTIVA" run --device "$serial" --no-build --flow missing.yaml || failures=$((failures+1))
run directory "$GRANTIVA" run --device "$serial" --no-build --flow flow-directory || failures=$((failures+1))
run configured-missing "$GRANTIVA" run --device "$serial" --no-build || failures=$((failures+1))
adb devices -l > "$base/adb-after.txt"; adb forward --list > "$base/forwards-after.txt"
find "$base" -type f -name 'failure-*.png' -print > "$base/failure-screenshots.txt"
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"; exit "$failures"
