#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-046-049-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input/.maestro" "$base/continue/report" "$base/timeout/report"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-continue-timeout-exact.sh"
cp "$script_path" "$base/input/controller-script.sh"
cp "$P/.maestro/99-crash.yaml" "$base/input/.maestro/99-crash.yaml"
cp "$P/.maestro/01-browse.yaml" "$base/input/.maestro/01-browse.yaml"
cp "$P/.maestro/coverage/18-long-wait.yaml" "$base/input/.maestro/18-long-wait.yaml"
cat > "$base/input/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
flows:
  - .maestro/99-crash.yaml
  - .maestro/01-browse.yaml
YAML
cd "$base/input"
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --continue-on-failure --report-dir %s\n' "$PWD" "$GRANTIVA" "$base/continue/report" > "$base/continue/commands.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --continue-on-failure --report-dir "$base/continue/report" > "$base/continue/stdout.log" 2> "$base/continue/stderr.log"; crc=$?
printf 'rc=%s\n' "$crc" >> "$base/continue/commands.txt"
cp "$base/continue/report/report.json" "$base/continue/report-preserved.json"

ready="$base/timeout/ready.json"
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --flow .maestro/18-long-wait.yaml --timeout 30 --ready-file %s --report-dir %s\n' "$PWD" "$GRANTIVA" "$ready" "$base/timeout/report" > "$base/timeout/commands.txt"
python3 -I -c 'import time; print(time.time())' > "$base/timeout/start-epoch.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --flow .maestro/18-long-wait.yaml --timeout 30 --ready-file "$ready" --report-dir "$base/timeout/report" > "$base/timeout/stdout.log" 2> "$base/timeout/stderr.log"; trc=$?
python3 -I -c 'import time; print(time.time())' > "$base/timeout/end-epoch.txt"
printf 'rc=%s\n' "$trc" >> "$base/timeout/commands.txt"
cp "$ready" "$base/timeout/ready-preserved.json"
cp "$base/timeout/report/report.json" "$base/timeout/report-preserved.json"
printf 'continue_rc=%s timeout_rc=%s\n' "$crc" "$trc" > "$base/exit-summary.txt"
# Both criteria require nonzero outcomes.
test "$crc" -ne 0
test "$trc" -ne 0
