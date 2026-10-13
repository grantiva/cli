#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/secondary-avd-lifecycle-exact-rerun1"
name="cov3-android-2"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-secondary-avd-lifecycle.sh" "$base/input/controller-script.sh"
cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app-free-debug.apk"
shasum -a 256 "$base/input/app-free-debug.apk" > "$base/input/app-free-debug.apk.sha256"
test -s "$base/input/app-free-debug.apk" || exit 5
cat > "$base/project/grantiva-android.yml" <<YAML
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: $name
YAML
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"

if avdmanager list avd -c | grep -Fxq "$name"; then echo "$name already exists; provenance must be reviewed" >&2; exit 3; fi
if [ -f "$HOME/.grantiva/android/created-avds.json" ] && grep -q "$name" "$HOME/.grantiva/android/created-avds.json"; then echo "$name already appears in created ledger" >&2; exit 4; fi
avdmanager list avd > "$base/avds-before.txt" 2> "$base/avds-before.err"
if [ -f "$HOME/.grantiva/android/created-avds.json" ]; then cp "$HOME/.grantiva/android/created-avds.json" "$base/created-before.json"; fi
if [ -f "$HOME/.grantiva/android/started.json" ]; then cp "$HOME/.grantiva/android/started.json" "$base/started-before.json"; fi

run_case() {
  local case_name="$1" expect="$2"
  shift 2
  local d="$base/$case_name"
  mkdir -p "$d"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; printf '\n'; } > "$d/commands.txt"
  "$@" > "$d/stdout.log" 2> "$d/stderr.log"
  local rc=$?
  printf 'rc=%s expected=%s\n' "$rc" "$expect" >> "$d/commands.txt"
  if [ "$expect" = zero ]; then [ "$rc" -eq 0 ]; else [ "$rc" -ne 0 ]; fi
}

cd "$base/project"
failures=0

# Fresh default-image creation without boot.
run_case AND-004-007 zero "$GRANTIVA" emulator ensure --name "$name" --no-boot || exit 6
avdmanager list avd > "$base/AND-004-007/avds-after.txt" 2> "$base/AND-004-007/avds-after.err"
cp "$HOME/.android/avd/$name.avd/config.ini" "$base/AND-004-007/config.ini"
cp "$HOME/.grantiva/android/created-avds.json" "$base/AND-004-007/created-avds.json"
touch "$base/ownership-established"
adb devices -l > "$base/AND-004-007/adb-after-no-boot.txt"
while read -r candidate; do
  [ -z "$candidate" ] && continue
  avd=$(adb -s "$candidate" emu avd name 2>/dev/null | tr -d '\r' | head -1)
  [ "$avd" != "$name" ] || { echo 'no-boot unexpectedly attached the secondary AVD' >&2; exit 7; }
done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')

# Config-selected headless boot, preserving process command and assigned serial.
run_case AND-005-006 zero "$GRANTIVA" emulator ensure --headless || exit 8
serial=""
for attempt in $(seq 1 60); do
  while read -r candidate; do
    [ -z "$candidate" ] && continue
    avd=$(adb -s "$candidate" emu avd name 2>/dev/null | tr -d '\r' | head -1)
    [ "$avd" = "$name" ] && serial="$candidate"
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  [ -n "$serial" ] && break
  sleep 1
done
[ -n "$serial" ] || { echo 'secondary owned AVD did not attach' >&2; exit 9; }
printf '%s\n' "$serial" > "$base/owned-secondary-serial.txt"
ps -axo pid,ppid,etime,command | grep "[q]emu-system.*-avd $name" > "$base/AND-005-006/qemu-process.txt"
cp "$HOME/.grantiva/android/started.json" "$base/AND-005-006/started.json"

# Repeating ensure must reuse the same attached serial; JSON must be valid.
run_case AND-003 zero "$GRANTIVA" emulator ensure --name "$name" || exit 10
printf '%s\n' "$serial" > "$base/AND-003/serial-before.txt"
adb devices -l > "$base/AND-003/adb-after.txt"
run_case AND-008 zero "$GRANTIVA" emulator ensure --name "$name" --json || exit 11
jq . "$base/AND-008/stdout.log" > "$base/AND-008/validated.json" || failures=$((failures + 1))

run_case AND-009 zero "$GRANTIVA" emulator sessions --json || exit 12
jq . "$base/AND-009/stdout.log" > "$base/AND-009/validated.json" || failures=$((failures + 1))

# Establish an owned UIAutomator2 session/forward, then teardown the exact secondary serial.
run_case AND-010-install zero "$GRANTIVA" build install --no-build --app-file "$base/input/app-free-debug.apk" --device "$serial" --no-launch || exit 13
run_case AND-010-start zero "$GRANTIVA" runner start --device "$serial" --detach --json || exit 14
[ -f .grantiva/session.json ] || { echo 'owned secondary runner did not publish session' >&2; exit 15; }
adb forward --list > "$base/AND-010-start/forwards.txt"
cp .grantiva/session.json "$base/AND-010-start/session.json"
run_case AND-010 zero "$GRANTIVA" emulator teardown --serial "$serial" || exit 16
for attempt in $(seq 1 20); do adb -s "$serial" get-state >/dev/null 2>&1 || break; sleep 1; done
adb devices -l > "$base/AND-010/adb-after.txt"
adb forward --list > "$base/AND-010/forwards-after.txt"
if [ -e .grantiva/session.json ]; then cp .grantiva/session.json "$base/AND-010/session-leftover.json"; failures=$((failures + 1)); fi

# Delete the stopped Grantiva-created AVD with structured output (covers AND-014/146).
[ -f "$base/ownership-established" ] && avdmanager list avd -c | grep -Fxq "$name" || { echo 'secondary ownership/existence guard failed before delete' >&2; exit 17; }
run_case AND-014-146 zero "$GRANTIVA" emulator delete --name "$name" --json || exit 18
jq . "$base/AND-014-146/stdout.log" > "$base/AND-014-146/validated.json" || failures=$((failures + 1))
avdmanager list avd -c > "$base/AND-014-146/avds-after.txt"

# Recreate, remove externally, and prove the next Grantiva call prunes its ownership record.
run_case AND-109-create zero "$GRANTIVA" emulator ensure --name "$name" --no-boot || exit 19
cp "$HOME/.grantiva/android/created-avds.json" "$base/AND-109-create/created-before-external-delete.json"
avdmanager list avd -c | grep -Fxq "$name" || exit 20
run_case AND-109-external-delete zero avdmanager delete avd -n "$name" || exit 21
run_case AND-109-prune zero "$GRANTIVA" emulator sessions --json || failures=$((failures + 1))
cp "$HOME/.grantiva/android/created-avds.json" "$base/AND-109-prune/created-after.json"
if grep -q "$name" "$base/AND-109-prune/created-after.json"; then failures=$((failures + 1)); fi

avdmanager list avd > "$base/avds-final.txt" 2> "$base/avds-final.err"
printf 'aggregate-failures=%s secondary-serial=%s\n' "$failures" "$serial" > "$base/summary.txt"
exit "$failures"
