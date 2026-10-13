#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B-C02.2-port-collision-rerun1"; name=cov3-android-port-r3; expected=emulator-5558
[ ! -e "$base" ] || exit 2; mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-bc022-port-collision-v1.sh" "$base/input/controller-script.sh"; uptime > "$base/uptime-before.txt"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
avdmanager list avd -c | grep -Fxq "$name" && exit 3; ! lsof -nP -iTCP:5556 -sTCP:LISTEN > "$base/port-before.txt" 2>&1 || exit 4; ! adb devices | awk 'NR>1{print $1}' | grep -Fxq "$expected" || exit 5
listener_pid=""; serial=""
cleanup(){ if [ -n "$serial" ]; then (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$serial" --force --json) >> "$base/trap-teardown.out" 2>> "$base/trap-teardown.err" || true; fi; avdmanager list avd -c | grep -Fxq "$name" && (cd "$base/project" && "$GRANTIVA" emulator delete --name "$name" --force --json) >> "$base/trap-delete.out" 2>> "$base/trap-delete.err" || true; if [ -n "$listener_pid" ] && kill -0 "$listener_pid" 2>/dev/null; then kill "$listener_pid" 2>/dev/null || true; wait "$listener_pid" 2>/dev/null || true; fi; }
trap cleanup EXIT
python3 -I - "$base/listener-ready.txt" <<'PY' &
import pathlib,socket,sys,time
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('127.0.0.1',5556)); s.listen(1); pathlib.Path(sys.argv[1]).write_text('ready\n'); time.sleep(600)
PY
listener_pid=$!; echo "$listener_pid" > "$base/listener.pid"; for i in $(seq 1 100); do [ -s "$base/listener-ready.txt" ] && break; kill -0 "$listener_pid" 2>/dev/null || exit 6; sleep .1; done; [ -s "$base/listener-ready.txt" ] || exit 7
lsof -nP -iTCP:5556 -sTCP:LISTEN > "$base/port-held.txt"; grep -q " $listener_pid " "$base/port-held.txt" || true
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$base/ensure.out" 2> "$base/ensure.err" || exit 8
serial="$(tail -1 "$base/ensure.out"|tr -d '[:space:]')"; [ "$serial" = "$expected" ] || exit 9; [ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 10
cp "$HOME/.grantiva/android/started.json" "$base/started.json"; qpid="$(ps -axo pid,command | awk -v n="$name" '$0 ~ /[q]emu-system/ && $0 ~ "-avd "n {print $1; exit}')"; [ -n "$qpid" ] || exit 11; ps -p "$qpid" -o pid,ppid,etime,command > "$base/qemu-process.txt"
trap - EXIT; cleanup; uptime > "$base/uptime-after.txt"; avdmanager list avd -c > "$base/avds-after.txt"; adb devices -l > "$base/adb-after.txt"
python3 -I - "$base" "$name" "$expected" "$qpid" "$listener_pid" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); name,serial,qpid,listener=sys.argv[2:]; started=json.loads((b/'started.json').read_text()); row=next((x for x in started if x.get('avd')==name),{})
checks={'listenerHeld5556':(b/'listener-ready.txt').read_text().strip()=='ready','successorSerial':serial=='emulator-5558','startedRecordExact':row.get('serial')==serial and str(row.get('pid'))==qpid,'qemuPIDExact':qpid in (b/'qemu-process.txt').read_text() and f'-avd {name}' in (b/'qemu-process.txt').read_text(),'ownedAVDRemoved':name not in (b/'avds-after.txt').read_text(),'primaryRetained':'emulator-5554' in (b/'adb-after.txt').read_text()}
(b/'decoded.json').write_text(json.dumps({'checks':checks,'record':row},indent=2)+'\n'); print(json.dumps(checks,sort_keys=True)); raise SystemExit(0 if all(checks.values()) else 1)
PY
