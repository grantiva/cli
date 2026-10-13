#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-018-external-run-rerun1"; name=cov3-android-external-r3; port=5574; serial=emulator-5574; adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb; emulator_bin=/Users/kyle/Library/Android/sdk/emulator/emulator; image='system-images;android-35;google_apis;arm64-v8a'
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and018-external-run-v1.sh" "$base/input/controller-script.sh"; cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"; cp "$W/findings/evidence/cov3-android/D2-09-shutdown-appfile-capture-rerun1/input/app.apk" "$base/input/app.apk"
avdmanager list avd -c | grep -Fxq "$name" && exit 3; ! $adb_bin devices | awk 'NR>1{print $1}' | grep -Fxq "$serial" || exit 4
for p in 5574 5575; do ! lsof -nP -iTCP:"$p" -sTCP:LISTEN > "$base/port-$p-before.txt" 2>&1 || exit 5; done
for f in created-avds.json started.json; do [ ! -f "$HOME/.grantiva/android/$f" ] || { cp "$HOME/.grantiva/android/$f" "$base/${f%.json}-before.json"; ! grep -Fqe "$name" -e "$serial" "$HOME/.grantiva/android/$f" || exit 6; }; done
printf 'no\n' | avdmanager create avd -n "$name" -k "$image" --force > "$base/create.out" 2> "$base/create.err" || exit 7
emupid=""
cleanup(){ if [ -n "$emupid" ] && ps -p "$emupid" -o command= 2>/dev/null | grep -Fq -- "-avd $name"; then kill -TERM "$emupid" 2>/dev/null || true; for i in $(seq 1 100); do kill -0 "$emupid" 2>/dev/null || break; sleep .1; done; kill -KILL "$emupid" 2>/dev/null || true; wait "$emupid" 2>/dev/null || true; fi; avdmanager list avd -c | grep -Fxq "$name" && avdmanager delete avd -n "$name" >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true; }
trap cleanup EXIT
"$emulator_bin" -avd "$name" -port "$port" -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect > "$base/emulator.out" 2> "$base/emulator.err" & emupid=$!; echo "$emupid" > "$base/emulator.pid"
ready=0; for i in $(seq 1 180); do [ "$($adb_bin -s "$serial" get-state 2>/dev/null)" = device ] && [ "$($adb_bin -s "$serial" shell getprop sys.boot_completed 2>/dev/null|tr -d '\r')" = 1 ] && { ready=1; break; }; kill -0 "$emupid" 2>/dev/null || break; sleep 1; done; [ "$ready" -eq 1 ] || exit 8
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 9
$adb_bin -s "$serial" install -r -t -d "$base/input/app.apk" > "$base/install.out" 2> "$base/install.err" || exit 10
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name") > "$base/ensure.out" 2> "$base/ensure.err"; echo "$?" > "$base/ensure.exit.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --device "$serial" --no-build --flow .maestro/01-browse.yaml --report-dir "$base/device-report") > "$base/device.out" 2> "$base/device.err"; echo "$?" > "$base/device.exit.txt"
(cd "$base/project" && "$GRANTIVA" run --platform android --emulator "$name" --no-build --flow .maestro/01-browse.yaml --report-dir "$base/emulator-report") > "$base/emulator-run.out" 2> "$base/emulator-run.err"; echo "$?" > "$base/emulator-run.exit.txt"
kill -0 "$emupid"; echo "$?" > "$base/process-alive-after.txt"; $adb_bin -s "$serial" get-state > "$base/device-state-after.txt"
for f in created-avds.json started.json; do [ ! -f "$HOME/.grantiva/android/$f" ] || cp "$HOME/.grantiva/android/$f" "$base/${f%.json}-after-runs.json"; done
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" "$name" "$serial" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name,serial=sys.argv[2:]; led='\n'.join(p.read_text() for p in b.glob('*-after-runs.json'))
def passed(p):
 j=json.loads((b/p/'report.json').read_text()); return j.get('status')=='passed'
checks={'ensureReusesExternal':(b/'ensure.exit.txt').read_text().strip()=='0','deviceRun0':(b/'device.exit.txt').read_text().strip()=='0' and passed('device-report'),'emulatorRun0':(b/'emulator-run.exit.txt').read_text().strip()=='0' and passed('emulator-report'),'externalStillAlive':(b/'process-alive-after.txt').read_text().strip()=='0' and (b/'device-state-after.txt').read_text().strip()=='device','neverRecorded':name not in led and serial not in led,'ownedAVDRemoved':name not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
