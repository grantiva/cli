#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B-C11.2-no-session-lazy-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-bc11-no-session-lazy-v1.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/bc11-no-session-lazy-client-v1.py" "$base/input/client.py"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
[ ! -e "$base/project/.grantiva/session.json" ] || exit 5
printf '# cwd=%s\n$ python3 -I %q %q %q %q %q\n' "$base/project" "$base/input/client.py" "$base/run" "$base/project" "$GRANTIVA" "$serial" > "$base/commands.txt"
python3 -I "$base/input/client.py" "$base/run" "$base/project" "$GRANTIVA" "$serial"; rc=$?
(cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/final-cleanup.out" 2> "$base/final-cleanup.err" || true
printf 'client=%s\n' "$rc" > "$base/summary.txt"
test "$rc" -eq 0 && test ! -e "$base/project/.grantiva/session.json"
