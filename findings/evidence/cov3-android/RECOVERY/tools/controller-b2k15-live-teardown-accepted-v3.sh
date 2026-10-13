#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K15-live-teardown-accepted-rerun3"
name="cov3-k15-owned-v3"
adb_bin=/Users/kyle/Library/Android/sdk/platform-tools/adb
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b2k15-live-teardown-accepted-v3.sh" "$base/input/controller-script.sh"
cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app-free-debug.apk"
shasum -a 256 "$base/input/app-free-debug.apk" > "$base/input/app-free-debug.apk.sha256"
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
avdmanager list avd -c > "$base/avds-before.txt"
if grep -Fxq "$name" "$base/avds-before.txt"; then echo owned-name-preexists >&2; exit 3; fi
primary="$($adb_bin devices | awk '$2=="device"{print $1}' | while read -r s; do n="$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; [ "$n" = cov3-android ] && echo "$s"; done)"
[ "$primary" = emulator-5554 ] || exit 4
$adb_bin -s "$primary" get-state > "$base/primary-before.txt" || exit 5
owned=0
secondary=""
cleanup(){
  if [ -z "$secondary" ]; then
    while read -r candidate; do [ -n "$candidate" ] || continue; candidate_name="$($adb_bin -s "$candidate" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; [ "$candidate_name" = "$name" ] && secondary="$candidate"; done < <($adb_bin devices | awk 'NR>1&&$2=="device"{print $1}')
  fi
  if [ -n "$secondary" ]; then
    actual="$($adb_bin -s "$secondary" emu avd name 2>/dev/null|tr -d '\r'|head -1)"
    if [ "$actual" = "$name" ]; then (cd "$base/project" && "$GRANTIVA" emulator teardown --serial "$secondary" --json) > "$base/trap-teardown.json" 2> "$base/trap-teardown.err" || true; for i in $(seq 1 30); do $adb_bin -s "$secondary" get-state >/dev/null 2>&1 || break; sleep 1; done; fi
  fi
  if [ "$owned" -eq 1 ] && avdmanager list avd -c | grep -Fxq "$name"; then "$GRANTIVA" emulator delete --name "$name" --json > "$base/trap-delete.json" 2> "$base/trap-delete.err" || true; fi
}
trap cleanup EXIT INT TERM
record(){ local d="$1"; shift; mkdir -p "$base/$d"; { printf '# cwd=%s\n$' "$base/project"; printf ' %q' "$@"; printf '\n'; } > "$base/$d/command.txt"; (cd "$base/project" && "$@") > "$base/$d/stdout.txt" 2> "$base/$d/stderr.txt"; local rc=$?; echo "$rc" > "$base/$d/exit.txt"; return "$rc"; }
record create "$GRANTIVA" emulator ensure --name "$name" --no-boot || exit 6
owned=1

boot_secondary(){
  local leg="$1"
  record "$leg/boot" "$GRANTIVA" emulator ensure --name "$name" --headless || return 1
  secondary=""
  for attempt in $(seq 1 90); do
    while read -r s; do [ -n "$s" ] || continue; n="$($adb_bin -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)"; [ "$n" = "$name" ] && secondary="$s"; done < <($adb_bin devices | awk 'NR>1&&$2=="device"{print $1}')
    [ -n "$secondary" ] && break; sleep 1
  done
  [ -n "$secondary" ] || return 2
  printf '%s\n' "$secondary" > "$base/$leg/owned-secondary-serial.txt"
  [ "$($adb_bin -s "$secondary" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || return 3
  record "$leg/install" "$GRANTIVA" build install --no-build --app-file "$base/input/app-free-debug.apk" --device "$secondary" --no-launch || return 4
  record "$leg/start" "$GRANTIVA" runner start --platform android --device "$secondary" --detach --json || return 5
  jq -e --arg s "$secondary" '.status=="started" and .serial==$s and (.pid|type)=="number"' "$base/$leg/start/stdout.txt" > "$base/$leg/start-validated.json" || return 6
  jq -r '.pid' "$base/$leg/start/stdout.txt" > "$base/$leg/runner-pid.txt"
  cp "$base/project/.grantiva/session.json" "$base/$leg/session-before.json"
  lease="$GRANTIVA_RUNNER_HOME/locks/$secondary.lock"
  printf '%s\n' "$lease" > "$base/$leg/lease-path.txt"
  test -f "$lease" || return 7
  cp "$lease" "$base/$leg/lease-before.txt"
}

boot_secondary text || exit 7
text_serial="$secondary"; text_pid="$(cat "$base/text/runner-pid.txt")"
record text/teardown "$GRANTIVA" emulator teardown --serial "$text_serial"; text_rc=$?
for i in $(seq 1 30); do $adb_bin -s "$text_serial" get-state >/dev/null 2>&1 || break; sleep 1; done
kill -0 "$text_pid" 2>/dev/null; text_pid_live=$?
$adb_bin -s "$text_serial" get-state > "$base/text/device-after.txt" 2> "$base/text/device-after.err"; text_device_live=$?
test ! -e "$base/project/.grantiva/session.json"; text_session_gone=$?
text_lease="$(cat "$base/text/lease-path.txt")"; test ! -e "$text_lease"; text_lease_gone=$?

boot_secondary json || exit 8
json_serial="$secondary"; json_pid="$(cat "$base/json/runner-pid.txt")"
record json/teardown "$GRANTIVA" emulator teardown --serial "$json_serial" --json; json_rc=$?
for i in $(seq 1 30); do $adb_bin -s "$json_serial" get-state >/dev/null 2>&1 || break; sleep 1; done
kill -0 "$json_pid" 2>/dev/null; json_pid_live=$?
$adb_bin -s "$json_serial" get-state > "$base/json/device-after.txt" 2> "$base/json/device-after.err"; json_device_live=$?
test ! -e "$base/project/.grantiva/session.json"; json_session_gone=$?
json_lease="$(cat "$base/json/lease-path.txt")"; test ! -e "$json_lease"; json_lease_gone=$?

$adb_bin -s "$primary" get-state > "$base/primary-after.txt" 2> "$base/primary-after.err"; primary_alive=$?
$adb_bin devices -l > "$base/adb-after.txt"
python3 -I - "$base" "$text_rc" "$text_pid_live" "$text_device_live" "$text_session_gone" "$json_rc" "$json_pid_live" "$json_device_live" "$json_session_gone" "$primary_alive" "$text_lease_gone" "$json_lease_gone" <<'PY'
import json,pathlib,sys
b=pathlib.Path(sys.argv[1]); text=(b/'text/teardown/stdout.txt').read_text()+(b/'text/teardown/stderr.txt').read_text(); raw=json.loads((b/'json/teardown/stdout.txt').read_text()); item=raw[0] if isinstance(raw,list) else raw
checks={'textAccepted':int(sys.argv[2])==0 and 'Stopped runner session' in text and 'Killed' in text,'textPidDead':int(sys.argv[3])!=0,'textDeviceGone':int(sys.argv[4])!=0,'textSessionGone':int(sys.argv[5])==0,'jsonAccepted':int(sys.argv[6])==0 and item.get('runnerSessionStopped') is True and item.get('killed') is True,'jsonPidDead':int(sys.argv[7])!=0,'jsonDeviceGone':int(sys.argv[8])!=0,'jsonSessionGone':int(sys.argv[9])==0,'unrelatedPrimaryAlive':int(sys.argv[10])==0,'textLeaseGone':int(sys.argv[11])==0,'jsonLeaseGone':int(sys.argv[12])==0}
(b/'assertions.json').write_text(json.dumps({'checks':checks,'jsonTeardown':item},indent=2,sort_keys=True)+'\n'); raise SystemExit(0 if all(checks.values()) else 1)
PY
rc=$?
record delete "$GRANTIVA" emulator delete --name "$name" --json || rc=$((rc+1))
avdmanager list avd -c > "$base/avds-after.txt"
grep -Fxq "$name" "$base/avds-after.txt" && rc=$((rc+1))
find "$GRANTIVA_RUNNER_HOME/locks" -maxdepth 1 -type f -print | sort > "$base/locks-after-delete.txt"
test ! -e "$GRANTIVA_RUNNER_HOME/locks/$text_serial.lock" || rc=$((rc+1))
test ! -e "$GRANTIVA_RUNNER_HOME/locks/$json_serial.lock" || rc=$((rc+1))
owned=0; secondary=""; trap - EXIT INT TERM
exit "$rc"
