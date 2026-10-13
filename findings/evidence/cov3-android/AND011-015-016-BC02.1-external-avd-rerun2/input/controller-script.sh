#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND011-015-016-BC02.1-external-avd-rerun2"; name=cov3-external-owned-r2; port=5574; serial=emulator-5574
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb; emulator_bin=/Users/kyle/Library/Android/sdk/emulator/emulator; image='system-images;android-35;google_apis;arm64-v8a'
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-external-avd-ownership-v2.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
avdmanager list avd -c > "$base/avds-before.txt"; $adb_bin devices -l > "$base/adb-before.txt"
[ "$($adb_bin -s emulator-5554 emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3
! avdmanager list avd -c | grep -Fxq "$name" || exit 4
! $adb_bin devices | awk 'NR>1{print $1}' | grep -Fxq "$serial" || exit 5
for p in 5574 5575; do ! lsof -nP -iTCP:"$p" -sTCP:LISTEN > "$base/port-$p-before.txt" 2>&1 || exit 5; done
for ledger in "$HOME/.grantiva/android/created-avds.json" "$HOME/.grantiva/android/started.json"; do [ ! -f "$ledger" ] || { cp "$ledger" "$base/$(basename "$ledger" .json)-before.json"; ! grep -Fqe "$name" -e "$serial" "$ledger" || exit 6; }; done
printf 'no\n' | avdmanager create avd -n "$name" -k "$image" --force > "$base/create.out" 2> "$base/create.err" || exit 7
touch "$base/ownership-established"
emupid=""
cleanup(){
 if $adb_bin -s "$serial" get-state >/dev/null 2>&1 && [ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ]; then (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force) > "$base/trap-teardown.out" 2> "$base/trap-teardown.err" || true; fi
 if [ -n "$emupid" ] && ps -p "$emupid" -o command= 2>/dev/null | grep -Fq -- "-avd $name"; then kill -TERM "$emupid" 2>/dev/null || true; for n in $(seq 1 20); do state=$(ps -p "$emupid" -o stat= 2>/dev/null|tr -d ' '); [ -z "$state" ] || [ "${state#Z}" != "$state" ] && break; sleep .1; done; kill -KILL "$emupid" 2>/dev/null || true; wait "$emupid" 2>/dev/null || true; fi
 avdmanager list avd -c | grep -Fxq "$name" && avdmanager delete avd -n "$name" > "$base/trap-delete.out" 2> "$base/trap-delete.err" || true
}
trap cleanup EXIT INT TERM
"$emulator_bin" -avd "$name" -port "$port" -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect > "$base/emulator.out" 2> "$base/emulator.err" & emupid=$!; echo "$emupid" > "$base/emulator.pid"
attached=0
for i in $(seq 1 180); do state="$($adb_bin -s "$serial" get-state 2>/dev/null || true)"; boot="$($adb_bin -s "$serial" shell getprop sys.boot_completed 2>/dev/null|tr -d '\r')"; if [ "$state" = device ] && [ "$boot" = 1 ]; then attached=1; break; fi; kill -0 "$emupid" 2>/dev/null || break; sleep 1; done
[ "$attached" -eq 1 ] || exit 8
[ "$($adb_bin -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 9
$adb_bin devices -l > "$base/adb-external-running.txt"; ps -p "$emupid" -o pid,ppid,etime,command > "$base/external-process.txt"
for ledger in "$HOME/.grantiva/android/created-avds.json" "$HOME/.grantiva/android/started.json"; do [ ! -f "$ledger" ] || cp "$ledger" "$base/$(basename "$ledger" .json)-while-external.json"; done
run(){ stem="$1"; shift; d="$base/$stem"; mkdir -p "$d"; { printf '# cwd=%s\n$' "$base/project"; printf ' %q' "$@"; printf '\n'; } > "$d/command.txt"; (cd "$base/project" && "$@") > "$d/stdout.txt" 2> "$d/stderr.txt"; rc=$?; echo "$rc" > "$d/exit.txt"; }
run teardown-refuse "$GRANTIVA" emulator teardown --serial "$serial"; trc=$(cat "$base/teardown-refuse/exit.txt")
kill -0 "$emupid" 2>/dev/null; alive_after_refuse=$?; $adb_bin -s "$serial" get-state > "$base/teardown-refuse/device-state.txt" 2>&1; state_after_refuse=$?
run primary-delete-force-refuse "$GRANTIVA" emulator delete --name cov3-android --force; prc=$(cat "$base/primary-delete-force-refuse/exit.txt")
$adb_bin -s emulator-5554 get-state > "$base/primary-delete-force-refuse/primary-state.txt" 2>&1; primary_alive=$?
run teardown-force "$GRANTIVA" emulator teardown --serial "$serial" --force; frc=$(cat "$base/teardown-force/exit.txt")
for i in $(seq 1 60); do $adb_bin -s "$serial" get-state >/dev/null 2>&1 || break; sleep 1; done
$adb_bin -s "$serial" get-state > "$base/teardown-force/device-state-after.txt" 2>&1; detached=$?
for i in $(seq 1 50); do state=$(ps -p "$emupid" -o stat= 2>/dev/null|tr -d ' '); [ -z "$state" ] || [ "${state#Z}" != "$state" ] && break; sleep .1; done
state=$(ps -p "$emupid" -o stat= 2>/dev/null|tr -d ' ')
if [ -n "$state" ] && [ "${state#Z}" = "$state" ]; then ps -p "$emupid" -o command= | grep -Fq -- "-avd $name" || exit 11; kill -TERM "$emupid" 2>/dev/null || true; for i in $(seq 1 20); do state=$(ps -p "$emupid" -o stat= 2>/dev/null|tr -d ' '); [ -z "$state" ] || [ "${state#Z}" != "$state" ] && break; sleep .1; done; kill -KILL "$emupid" 2>/dev/null || true; fi
wait "$emupid" 2>/dev/null; emurc=$?; emupid=""
avdmanager list avd -c | grep -Fxq "$name" || exit 10
run delete-refuse "$GRANTIVA" emulator delete --name "$name"; drc=$(cat "$base/delete-refuse/exit.txt")
avdmanager list avd -c | grep -Fxq "$name"; exists_after_refuse=$?
run delete-force "$GRANTIVA" emulator delete --name "$name" --force; dfc=$(cat "$base/delete-force/exit.txt")
avdmanager list avd -c | grep -Fxq "$name"; absent_after_force=$?
$adb_bin devices -l > "$base/adb-after.txt"; avdmanager list avd -c > "$base/avds-after.txt"
for ledger in "$HOME/.grantiva/android/created-avds.json" "$HOME/.grantiva/android/started.json"; do [ ! -f "$ledger" ] || cp "$ledger" "$base/$(basename "$ledger" .json)-after.json"; done
trap - EXIT INT TERM
python3 -I - "$base" "$trc" "$alive_after_refuse" "$state_after_refuse" "$prc" "$primary_alive" "$frc" "$detached" "$emurc" "$drc" "$exists_after_refuse" "$dfc" "$absent_after_force" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); v=list(map(int,sys.argv[2:])); trc,alive,state,prc,primary,frc,detached,emurc,drc,exists,dfc,absent=v
text=lambda n: ((b/n/'stdout.txt').read_text()+(b/n/'stderr.txt').read_text())
checks={'teardownRefusesWithoutForce':trc!=0 and '--force' in text('teardown-refuse'),'externalStillAliveAfterRefusal':alive==0 and state==0,'primaryRunningDeleteForceRefused':prc!=0 and primary==0 and 'running' in text('primary-delete-force-refuse').lower(),'forceTeardownSucceeds':frc==0 and detached!=0,'manualProcessReaped':emurc in (0,130,143,137),'deleteRefusesWithoutForce':drc!=0 and exists==0 and '--force' in text('delete-refuse'),'forceDeleteSucceeds':dfc==0 and absent!=0,'primaryAdbUnchanged': 'emulator-5554' in (b/'adb-after.txt').read_text(),'ownedNameAbsent':'cov3-external-owned-r2' not in (b/'avds-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
