#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L18-run-wait15-complement-rerun1"
src="$E/wait-screens-complement-rerun2/project"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
test -f "$src/grantiva-android.yml" || exit 3
test -f "$src/.maestro/coverage/14-runflow-sub.yaml" || exit 4
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l18-run-wait15-v1.sh" "$base/input/controller-script.sh"
cp -R "$src/." "$base/project/"
cp "$src/grantiva-android.yml" "$base/input/grantiva-android.yml"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 5
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 6
printf '# cwd=%s\n$ %q run --platform android --device %q --no-build\n' "$base/project" "$GRANTIVA" "$serial" > "$base/command.txt"
t0="$(python3 -I -c 'import time;print(time.monotonic())')"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build) > "$base/stdout.txt" 2> "$base/stderr.txt"; rc=$?
t1="$(python3 -I -c 'import time;print(time.monotonic())')"
python3 -I - "$base" "$t0" "$t1" "$rc" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); out=(b/'stdout.txt').read_text(); err=(b/'stderr.txt').read_text()
checks={
 'exit0':int(sys.argv[4])==0,
 'wait3': 'Wait 3s' in out,
 'wait15': 'Wait 1.5s' in out,
 'noEvalScript': 'evalScript' not in out+err,
 'exactMarkers': '(exact)' in out,
}
(b/'result.json').write_text(json.dumps({'elapsedSeconds':float(sys.argv[3])-float(sys.argv[2]),'exitCode':int(sys.argv[4])},indent=2)+'\n')
(b/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
raise SystemExit(0 if all(checks.values()) else 1)
PY
