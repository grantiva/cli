#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/AND-125-exact-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/output" "$d/input"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-record-doc-example.sh"; cp "$script_path" "$d/input/controller-script.sh"
printf '# docs/android.md example at candidate 8f2cff67 line 151\n# cwd=%s\n$ %s record --device emulator-5554 --duration 5 --frames-at 0,1000,3000 --output %s\n' "$P" "$GRANTIVA" "$d/output/example.mp4" > "$d/commands.txt"
"$GRANTIVA" record --device emulator-5554 --duration 5 --frames-at 0,1000,3000 --output "$d/output/example.mp4" > "$d/stdout.log" 2> "$d/stderr.log"; rc=$?
printf 'rc=%s\n' "$rc" >> "$d/commands.txt"
find "$d/output" -maxdepth 1 -type f -print | sort > "$d/files.txt"
test "$rc" -eq 0
test "$(find "$d/output" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')" -eq 3
test -s "$d/output/example.mp4"
