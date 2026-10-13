#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L50-live-count-complement-rerun1"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/report"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l50-live-count-v1.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cat > "$base/project/.maestro/live-count.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- assertVisible: {text: "Golden Gate Bridge", count: 2}
YAML
cp "$base/project/.maestro/live-count.yaml" "$base/input/"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 3
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
python3 -I -c 'import json,os;print(json.dumps({"load1":os.getloadavg()[0]}))' > "$base/host-load-before.json"
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --flow .maestro/live-count.yaml --report-dir %q\n' "$base/project" "$GRANTIVA" "$serial" "$base/report" > "$base/command.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/live-count.yaml --report-dir "$base/report") > "$base/stdout.txt" 2> "$base/stderr.txt"; rc=$?
printf '%s\n' "$rc" > "$base/exit.txt"; test "$rc" -eq 0
