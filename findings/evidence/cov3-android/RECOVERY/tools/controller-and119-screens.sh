#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-119-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/fail/project/.maestro" "$base/fail/report" "$base/slow/project" "$base/slow/report" "$base/input"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and119-screens.sh"; cp "$script_path" "$base/input/controller-script.sh"
cp "$P/.maestro/coverage/cfg/screens-fail.grantiva-android.yml" "$base/fail/project/grantiva-android.yml"
cp "$P/.maestro/01-browse.yaml" "$base/fail/project/.maestro/"
cp "$P/.maestro/coverage/cfg/screens-slow.grantiva-android.yml" "$base/slow/project/grantiva-android.yml"
cd "$base/fail/project"
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --continue-on-failure --report-dir %s\n' "$PWD" "$GRANTIVA" "$base/fail/report" > "$base/fail/commands.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --continue-on-failure --report-dir "$base/fail/report" > "$base/fail/stdout.log" 2> "$base/fail/stderr.log"; frc=$?
printf 'rc=%s\n' "$frc" >> "$base/fail/commands.txt"
cd "$base/slow/project"
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --timeout 30 --report-dir %s\n' "$PWD" "$GRANTIVA" "$base/slow/report" > "$base/slow/commands.txt"
python3 -I -c 'import time; print(time.time())' > "$base/slow/start-epoch.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --timeout 30 --report-dir "$base/slow/report" > "$base/slow/stdout.log" 2> "$base/slow/stderr.log"; src=$?
python3 -I -c 'import time; print(time.time())' > "$base/slow/end-epoch.txt"
printf 'rc=%s\n' "$src" >> "$base/slow/commands.txt"
printf 'fail_rc=%s slow_rc=%s\n' "$frc" "$src" > "$base/exit-summary.txt"
test "$frc" -ne 0; test "$src" -ne 0
