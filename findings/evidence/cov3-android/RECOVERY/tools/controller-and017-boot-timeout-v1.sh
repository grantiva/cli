#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-017-boot-timeout-rerun1"; name=cov3-android-timeout-r3
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and017-boot-timeout-v1.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
avdmanager list avd -c | grep -Fxq "$name" && exit 3
for f in created-avds.json started.json; do [ ! -f "$HOME/.grantiva/android/$f" ] || { cp "$HOME/.grantiva/android/$f" "$base/${f%.json}-before.json"; ! grep -Fq "$name" "$HOME/.grantiva/android/$f" || exit 4; }; done
owned_pid=""
cleanup(){
 if [ -n "$owned_pid" ] && kill -0 "$owned_pid" 2>/dev/null; then kill "$owned_pid" 2>/dev/null || true; for i in $(seq 1 100); do kill -0 "$owned_pid" 2>/dev/null || break; sleep .1; done; kill -9 "$owned_pid" 2>/dev/null || true; wait "$owned_pid" 2>/dev/null || true; fi
 avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --no-boot) > "$base/create.out" 2> "$base/create.err" || exit 5
start="$(python3 -I -c 'import time;print(time.monotonic())')"
(cd "$base/project" && GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS=5 "$GRANTIVA" emulator ensure --name "$name") > "$base/ensure.out" 2> "$base/ensure.err"; rc=$?
end="$(python3 -I -c 'import time;print(time.monotonic())')"; echo "$rc" > "$base/ensure.exit.txt"; python3 -I -c 'import sys;print(float(sys.argv[2])-float(sys.argv[1]))' "$start" "$end" > "$base/elapsed.txt"
ps -axo pid,ppid,etime,command | grep "[q]emu-system.*-avd $name" > "$base/qemu-after-timeout.txt" || true
owned_pid="$(awk 'NR==1{print $1}' "$base/qemu-after-timeout.txt")"; [ -n "$owned_pid" ] || exit 6
adb devices -l > "$base/adb-after-timeout.txt"; cp "$HOME/.grantiva/android/started.json" "$base/started-after-timeout.json"; cp "$HOME/.grantiva/android/created-avds.json" "$base/created-after-timeout.json"
trap - EXIT; cleanup; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" "$name" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name=sys.argv[2]; text=(b/'ensure.out').read_text()+(b/'ensure.err').read_text(); elapsed=float((b/'elapsed.txt').read_text()); started=(b/'started-after-timeout.json').read_text(); created=(b/'created-after-timeout.json').read_text()
checks={'timeoutExit1':(b/'ensure.exit.txt').read_text().strip()=='1','elapsedNearFive':5<=elapsed<12,'exactTimeoutReason':'did not finish booting within 5s' in text,'remedyNamesEnv':'GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS' in text,'spawnedProcessStillAlive':bool((b/'qemu-after-timeout.txt').read_text().strip()),'startedRecordRetained':name in started,'createdRecordRetained':name in created,'ownedAVDRemoved':name not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'elapsed':elapsed,'text':text},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
