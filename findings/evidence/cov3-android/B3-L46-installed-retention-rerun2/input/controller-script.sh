#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L46-installed-retention-rerun2"; name=cov3-android-retention-r3b
if [ -e "$base" ] || avdmanager list avd -c | grep -Fxq "$name"; then echo refusing-existing >&2; exit 2; fi
mkdir -p "$base/input" "$base/project" "$base/cycles"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3l46-installed-retention-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app.apk"
shasum -a 256 "$base/input/app.apk" > "$base/input/app.apk.sha256"; test -s "$base/input/app.apk" || exit 3
owned=0; serial=''
cleanup(){ if [ "$owned" -eq 1 ]; then if [ -n "$serial" ] && [ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ]; then "$GRANTIVA" emulator teardown --serial "$serial" --force > "$base/trap-teardown.out" 2> "$base/trap-teardown.err" || true; fi; "$GRANTIVA" emulator delete --name "$name" --force --json > "$base/trap-delete.out" 2> "$base/trap-delete.err" || true; fi; }
trap cleanup EXIT INT TERM
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$base/ensure.out" 2> "$base/ensure.err"; [ "$?" -eq 0 ] || exit 4; owned=1
for attempt in $(seq 1 90); do while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] && break; sleep 1; done
[ -n "$serial" ] || exit 5
adb devices -l > "$base/adb-before.txt"
failures=0
for n in 1 2 3; do
 d="$base/cycles/$n"; mkdir -p "$d"; printf '%s\n' "$serial" > "$d/serial-before.txt"
 (cd "$base/project" && "$GRANTIVA" build install --platform android --device "$serial" --no-build --no-launch --app-file "$base/input/app.apk") > "$d/install.out" 2> "$d/install.err"; irc=$?
 printf '%s\n' "$irc" > "$d/install.exit.txt"; [ "$irc" -eq 0 ] || failures=$((failures+1))
 sleep 5
 t0="$(python3 -I -c 'import time;print(time.monotonic())')"
 (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --verbose --json) > "$d/teardown.json" 2> "$d/teardown.err"; trc=$?
 t1="$(python3 -I -c 'import time;print(time.monotonic())')"; python3 -I -c 'import sys;print(float(sys.argv[2])-float(sys.argv[1]))' "$t0" "$t1" > "$d/teardown-elapsed.txt"
 for attempt in $(seq 1 40); do adb -s "$serial" get-state >/dev/null 2>&1 || break; sleep .25; done
 (cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$d/ensure.out" 2> "$d/ensure.err"; erc=$?
 serial=''; for attempt in $(seq 1 90); do while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] && break; sleep 1; done
 adb -s "$serial" shell pm list packages com.kylebrowning.landmarks > "$d/packages.txt" 2> "$d/packages.err"; prc=$?
 elapsed="$(cat "$d/teardown-elapsed.txt")"
 python3 -I - "$d" "$trc" "$erc" "$prc" "$elapsed" <<'PY'
import json,pathlib,sys
d=pathlib.Path(sys.argv[1]); doc=json.loads((d/'teardown.json').read_text()); checks={'teardown0':int(sys.argv[2])==0,'ensure0':int(sys.argv[3])==0,'packageQuery0':int(sys.argv[4])==0,'install0':int((d/'install.exit.txt').read_text())==0,'under30s':float(sys.argv[5])<30,'killedTrue':doc.get('killed') is True,'syncNarrated':'sync' in (d/'teardown.err').read_text().lower(),'packageRetained':'com.kylebrowning.landmarks' in (d/'packages.txt').read_text()}; (d/'assertions.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
 [ "$?" -eq 0 ] || failures=$((failures+1))
done
printf '%s\n' "$failures" > "$base/failures.txt"
cleanup; owned=0; trap - EXIT INT TERM
adb devices -l > "$base/adb-after.txt"
[ "$(adb -s emulator-5554 emu avd name 2>/dev/null|tr -d '\\r'|head -1)" = cov3-android ] || exit 7
test "$failures" -eq 0
