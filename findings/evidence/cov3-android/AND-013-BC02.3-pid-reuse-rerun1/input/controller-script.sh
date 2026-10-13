#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-013-BC02.3-pid-reuse-rerun1"; name=cov3-android-reuse-r3; emulator_bin=/Users/kyle/Library/Android/sdk/emulator/emulator
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and013-bc023-pid-reuse-v1.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
avdmanager list avd -c | grep -Fxq "$name" && exit 3
external_pid=""; serial=""
cleanup(){
 if [ -n "$serial" ]; then (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; fi
 if [ -n "$external_pid" ] && ps -p "$external_pid" -o command= 2>/dev/null | grep -Fq -- "-avd $name"; then kill "$external_pid" 2>/dev/null || true; for i in $(seq 1 100); do kill -0 "$external_pid" 2>/dev/null || break; sleep .1; done; kill -9 "$external_pid" 2>/dev/null || true; wait "$external_pid" 2>/dev/null || true; fi
 avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$base/ensure.out" 2> "$base/ensure.err" || exit 4
serial="$(tail -1 "$base/ensure.out"|tr -d '[:space:]')"; [ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 5
port="${serial#emulator-}"; old_pid="$(ps -axo pid,command | awk -v n="$name" '$0 ~ /[q]emu-system/ && $0 ~ "-avd "n {print $1; exit}')"; [ -n "$old_pid" ] || exit 6
cp "$HOME/.grantiva/android/started.json" "$base/started-owned.json"; grep -Fq "$name" "$base/started-owned.json" || exit 7
ps -p "$old_pid" -o pid,ppid,etime,command > "$base/old-process.txt"; kill -9 "$old_pid"; wait "$old_pid" 2>/dev/null || true
for i in $(seq 1 100); do adb -s "$serial" get-state >/dev/null 2>&1 || break; sleep .1; done
"$emulator_bin" -avd "$name" -port "$port" -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect > "$base/external-emulator.out" 2> "$base/external-emulator.err" & external_pid=$!; echo "$external_pid" > "$base/external.pid"
ready=0; for i in $(seq 1 180); do [ "$(adb -s "$serial" get-state 2>/dev/null)" = device ] && [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null|tr -d '\r')" = 1 ] && { ready=1; break; }; kill -0 "$external_pid" 2>/dev/null || break; sleep 1; done; [ "$ready" -eq 1 ] || exit 8
[ "$external_pid" != "$old_pid" ] || exit 9; ps -p "$external_pid" -o pid,ppid,etime,command > "$base/new-process.txt"
(cd "$base/project" && "$GRANTIVA" emulator sessions --json) > "$base/sessions.json" 2> "$base/sessions.err"; echo "$?" > "$base/sessions.exit.txt"; cp "$HOME/.grantiva/android/started.json" "$base/started-after-sessions.json"
(cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial") > "$base/refuse.out" 2> "$base/refuse.err"; echo "$?" > "$base/refuse.exit.txt"
kill -0 "$external_pid"; echo "$?" > "$base/external-alive-after-refuse.txt"; adb -s "$serial" get-state > "$base/device-after-refuse.txt"
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" "$name" "$serial" "$old_pid" "$external_pid" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name,serial,old,new=sys.argv[2:]; sessions=json.loads((b/'sessions.json').read_text()); started=(b/'started-after-sessions.json').read_text(); refusal=(b/'refuse.out').read_text()+(b/'refuse.err').read_text()
checks={'distinctReplacementPID':old!=new,'sessions0':(b/'sessions.exit.txt').read_text().strip()=='0','staleRecordPruned':old not in started and name not in started and serial not in started,'sessionsExcludeReplacement':all(str(x.get('pid'))!=new and x.get('serial')!=serial for x in sessions),'nonForceRefuses':(b/'refuse.exit.txt').read_text().strip()!='0' and '--force' in refusal,'refusalNamesSerial':serial in refusal,'replacementSurvivesRefusal':(b/'external-alive-after-refuse.txt').read_text().strip()=='0' and (b/'device-after-refuse.txt').read_text().strip()=='device','ownedAVDRemoved':name not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'sessions':sessions},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
