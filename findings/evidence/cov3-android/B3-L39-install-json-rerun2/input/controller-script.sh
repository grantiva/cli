#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L39-install-json-rerun2"
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/runs"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l39-install-json-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/grantiva-android.yml"
cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app.apk"
shasum -a 256 "$base/input/app.apk" > "$base/input/app.apk.sha256"; test -s "$base/input/app.apk" || exit 3
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
serial="$($adb_bin devices | awk '$2=="device"&&$1~/^emulator-/{print $1}')"
[ "$serial" = emulator-5554 ] || exit 4
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 5
run_case(){ name="$1"; gradle="$2"; shift 2; d="$base/runs/$name"; mkdir -p "$d"; load="$(python3 -I -c 'import os;print(os.getloadavg()[0])')"; printf '%s\n' "$load" > "$d/load1-before.txt"; if [ "$gradle" = yes ]; then python3 -I -c 'import sys;raise SystemExit(0 if float(sys.argv[1])<20 else 1)' "$load" || return 99; fi; printf '# cwd=%s\n$' "$P" > "$d/command.txt"; printf ' %q' "$@" >> "$d/command.txt"; printf '\n' >> "$d/command.txt"; (cd "$P" && "$@") > "$d/stdout.json" 2> "$d/stderr.txt"; rc=$?; printf '%s\n' "$rc" > "$d/exit.txt"; return 0; }
run_case launched yes "$GRANTIVA" build install --platform android --device "$serial" --json || exit 6
run_case installed yes "$GRANTIVA" build install --platform android --device "$serial" --no-launch --json || exit 7
run_case skipped no "$GRANTIVA" build install --platform android --device "$serial" --no-build --no-launch --json || exit 8
run_case app-file no "$GRANTIVA" build install --platform android --device "$serial" --no-build --app-file "$base/input/app.apk" --no-launch --json || exit 9
python3 -I - "$base" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); docs={n:json.loads((b/'runs'/n/'stdout.json').read_text()) for n in ['launched','installed','skipped','app-file']}; exits={n:int((b/'runs'/n/'exit.txt').read_text()) for n in docs}
checks={'allExit0':all(v==0 for v in exits.values()),'everyAppPathKey':all('appPath' in d for d in docs.values()),'launchedStatus':docs['launched'].get('status')=='launched','installedStatus':docs['installed'].get('status')=='installed','skippedStatus':docs['skipped'].get('status')=='skipped','skippedNulls':all(docs['skipped'].get(k) is None for k in ['appPath','scheme','dataContainerPath']),'appFilePath':docs['app-file'].get('appPath')==str((b/'input/app.apk').resolve())}
(b/'decoded.json').write_text(json.dumps({'documents':docs,'checks':checks},indent=2)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
