#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/PHASEB-build-lifecycle-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-phaseb-build-lifecycle.sh"
cp "$script_path" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config-at-start.yml"
cp "$P/grantiva-android.yml" "$base/input/stock-config.yml"
sed '/^emulator:/d' "$P/grantiva-android.yml" > "$base/input/no-emulator-config.yml"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app-free-debug.apk"
grep -q '^emulator: cov3-android$' "$base/input/stock-config.yml" || { echo 'frozen stock config does not select cov3-android' >&2; exit 10; }
test -s "$base/input/app-free-debug.apk" || { echo 'frozen APK is missing or empty' >&2; exit 11; }
cd "$P"

restore_config() { cp "$base/input/config-at-start.yml" "$P/grantiva-android.yml"; }
trap restore_config EXIT

snapshot() {
  local name="$1"
  adb devices -l > "$base/$name-adb.txt"
  adb forward --list > "$base/$name-forwards.txt"
  ps -axo pid,ppid,etime,command | grep -E '[q]emu-system.*-avd cov3-android|[g]rantiva-runner.*android' > "$base/$name-processes.txt" || true
}

require_only_owned_android() {
  local serial avd
  while read -r serial; do
    [ -z "$serial" ] && continue
    case "$serial" in emulator-*) ;; *) echo "unexpected physical Android device: $serial" >&2; exit 3;; esac
    avd=$(adb -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)
    if [ "$avd" != "cov3-android" ]; then echo "attached emulator $serial is not owned cov3-android: $avd" >&2; exit 4; fi
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
}

owned_serial() {
  local serial avd found=""
  while read -r serial; do
    [ -z "$serial" ] && continue
    avd=$(adb -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)
    if [ "$avd" = "cov3-android" ]; then
      if [ -n "$found" ]; then echo 'more than one cov3-android serial attached' >&2; return 1; fi
      found="$serial"
    fi
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

wait_gradle_load() {
  local label="$1" load attempt
  mkdir -p "$base/load"
  for attempt in $(seq 1 120); do
    load=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')
    printf '%s attempt=%s one-minute-load=%s\n' "$(date -u +%FT%TZ)" "$attempt" "$load" >> "$base/load/$label.txt"
    python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 20 else 1)' "$load" && return 0
    sleep 5
  done
  echo "load stayed >=20 before $label" >&2
  return 1
}

run_cmd() {
  local name="$1"
  local expect="$2"
  shift 2
  mkdir -p "$base/$name"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; printf '\n'; } > "$base/$name/commands.txt"
  "$@" > "$base/$name/stdout.log" 2> "$base/$name/stderr.log"
  local rc=$?
  printf 'rc=%s expected=%s\n' "$rc" "$expect" >> "$base/$name/commands.txt"
  if [ "$expect" = zero ]; then [ "$rc" -eq 0 ]; else [ "$rc" -ne 0 ]; fi
}

stop_owned() {
  require_only_owned_android
  local serial
  if serial=$(owned_serial); then
    printf '%s\n' "$serial" > "$base/$1-owned-serial.txt"
    run_cmd "$1-teardown" zero "$GRANTIVA" emulator teardown --serial "$serial"
  else
    mkdir -p "$base/$1-teardown"
    echo 'owned emulator already stopped' > "$base/$1-teardown/commands.txt"
  fi
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    owned_serial >/dev/null 2>&1 || return 0
    sleep 1
  done
  echo 'owned emulator did not stop' >&2
  return 1
}

failures=0
require_only_owned_android
snapshot before

# Exactly one running emulator, with no emulator configured, must be selected.
cp "$base/input/no-emulator-config.yml" grantiva-android.yml
run_cmd AND-036 zero "$GRANTIVA" run --no-build --flow .maestro/01-browse.yaml --report-dir "$base/AND-036/report" || failures=$((failures + 1))

# The compatibility flag is accepted and the settings lifecycle still completes.
cp "$base/input/stock-config.yml" grantiva-android.yml
run_cmd AND-145 zero "$GRANTIVA" run --allow-device-settings --emulator cov3-android --no-build --flow .maestro/01-browse.yaml --report-dir "$base/AND-145/report" || failures=$((failures + 1))

# build build compiles only and must not boot the configured AVD.
stop_owned AND-111 || exit 5
snapshot AND-111-before
wait_gradle_load AND-111 || exit 20
run_cmd AND-111 zero "$GRANTIVA" build build || failures=$((failures + 1))
snapshot AND-111-after

# With no configured emulator and none attached, run fails while listing choices and boots nothing.
cp "$base/input/no-emulator-config.yml" grantiva-android.yml
cp grantiva-android.yml "$base/AND-114-config-under-test.yml"
avdmanager list avd > "$base/AND-114-avds-before.txt" 2> "$base/AND-114-avds-before.err"
avd_count=$(grep -c '^    Name: ' "$base/AND-114-avds-before.txt")
if [ "$avd_count" -lt 2 ]; then echo "AND-114 requires multiple AVD choices; observed $avd_count" >&2; exit 12; fi
if [ -f "$HOME/.grantiva/android/started.json" ]; then cp "$HOME/.grantiva/android/started.json" "$base/AND-114-started-before.json"; fi
run_cmd AND-114 nonzero "$GRANTIVA" run --no-build --flow .maestro/01-browse.yaml --report-dir "$base/AND-114/report" || failures=$((failures + 1))
snapshot AND-114-after
avdmanager list avd > "$base/AND-114-avds-after.txt" 2> "$base/AND-114-avds-after.err"
if [ -f "$HOME/.grantiva/android/started.json" ]; then cp "$HOME/.grantiva/android/started.json" "$base/AND-114-started-after.json"; fi

# build install boots the configured owned emulator and logs its selected serial.
cp "$base/input/stock-config.yml" grantiva-android.yml
wait_gradle_load AND-113 || exit 21
run_cmd AND-113 zero "$GRANTIVA" build install || failures=$((failures + 1))
snapshot AND-113-after

# Explicit module/emulator/headless install from a stopped state.
stop_owned AND-143 || exit 6
wait_gradle_load AND-143 || exit 22
run_cmd AND-143 zero "$GRANTIVA" build install --emulator cov3-android --headless --module app || failures=$((failures + 1))
snapshot AND-143-after

# Explicit emulator run boots and completes from a stopped state.
stop_owned AND-029 || exit 7
run_cmd AND-029 zero "$GRANTIVA" run --emulator cov3-android --no-build --flow .maestro/01-browse.yaml --report-dir "$base/AND-029/report" || failures=$((failures + 1))
snapshot AND-029-after

# Headless explicit emulator run includes -no-window in the owned QEMU process.
stop_owned AND-032 || exit 8
run_cmd AND-032 zero "$GRANTIVA" run --headless --emulator cov3-android --no-build --flow .maestro/01-browse.yaml --report-dir "$base/AND-032/report" || failures=$((failures + 1))
snapshot AND-032-after

# Diff build/capture honors explicit emulator, module, variant, and headless flags.
stop_owned AND-140 || exit 9
wait_gradle_load AND-140 || exit 23
run_cmd AND-140 zero "$GRANTIVA" diff capture --emulator cov3-android --module app --variant freeDebug --headless || failures=$((failures + 1))
snapshot AND-140-after
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-140/captures"; else failures=$((failures + 1)); fi

# A prebuilt APK bypasses Gradle and yields all configured captures.
run_cmd AND-141 zero "$GRANTIVA" diff capture --app-file "$base/input/app-free-debug.apk" --verbose || failures=$((failures + 1))
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-141/captures"; else failures=$((failures + 1)); fi

# All compare-and-capture targeting variants operate on the owned emulator.
wait_gradle_load AND-142-emulator || exit 24
run_cmd AND-142-emulator zero "$GRANTIVA" diff compare --capture --emulator cov3-android --module app --variant freeDebug --application-id com.kylebrowning.landmarks --headless || failures=$((failures + 1))
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-142-emulator/captures"; else failures=$((failures + 1)); fi
current_serial=$(owned_serial) || exit 25
mkdir -p "$base/AND-142-device"
printf '%s\n' "$current_serial" > "$base/AND-142-device/owned-serial.txt"
run_cmd AND-142-device zero "$GRANTIVA" diff compare --capture --device "$current_serial" --no-build || failures=$((failures + 1))
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-142-device/captures"; else failures=$((failures + 1)); fi
run_cmd AND-142-appfile zero "$GRANTIVA" diff compare --capture --app-file "$base/input/app-free-debug.apk" || failures=$((failures + 1))
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-142-appfile/captures"; else failures=$((failures + 1)); fi
run_cmd AND-142-settings zero "$GRANTIVA" diff compare --capture --allow-device-settings --device "$current_serial" --no-build || failures=$((failures + 1))
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/AND-142-settings/captures"; else failures=$((failures + 1)); fi

snapshot final
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
