#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/android-settings-lifecycle-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-android-settings-lifecycle.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
cp "$P/.maestro/11-slow.yaml" "$base/input/11-slow.yaml"
candidate=/Users/kyle/Developer/grantiva-cli/.worktrees/release-main
git -C "$candidate" rev-parse HEAD > "$base/input/candidate-head.txt"
grep -q '^8f2cff67' "$base/input/candidate-head.txt" || { echo 'candidate source head changed' >&2; exit 4; }
sed -n '35,47p' "$candidate/Sources/GrantivaCore/Android/AndroidCaptureSettings.swift" > "$base/input/state-path-source.txt"
cd "$P"

owned_serial() {
  local s avd found=""
  while read -r s; do
    [ -z "$s" ] && continue
    avd=$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)
    [ "$avd" = cov3-android ] || { echo "unexpected attached device $s ($avd)" >&2; return 1; }
    [ -z "$found" ] || return 1
    found="$s"
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

snapshot_settings() {
  local label="$1"
  local d="$base/$2"
  mkdir -p "$d"
  for key in sysui_demo_allowed window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$serial" shell settings get global "$key" > "$d/$label-$key.txt" 2> "$d/$label-$key.err"
  done
  adb -s "$serial" shell dumpsys input > "$d/$label-dumpsys-input.txt" 2> "$d/$label-dumpsys-input.err"
  adb -s "$serial" shell dumpsys battery > "$d/$label-dumpsys-battery.txt" 2> "$d/$label-dumpsys-battery.err"
  adb -s "$serial" exec-out screencap -p > "$d/$label-screen.png" 2> "$d/$label-screen.err"
}

run_observed() {
  local name="$1"
  local extra="$2"
  local d="$base/$name"
  local state="$P/.grantiva/android-settings-$serial.json"
  mkdir -p "$d/report"
  if [ -e "$state" ]; then
    cp "$state" "$d/unexpected-state-before-run.json"
    echo "refusing stale settings state: $state" >&2
    return 1
  fi
  snapshot_settings before "$name"
  printf '# cwd=%s\n$ %q run --device %q --no-build --flow .maestro/11-slow.yaml --report-dir %q %s\n' "$PWD" "$GRANTIVA" "$serial" "$d/report" "$extra" > "$d/commands.txt"
  if [ -n "$extra" ]; then
    "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/11-slow.yaml --report-dir "$d/report" "$extra" > "$d/stdout.log" 2> "$d/stderr.log" &
  else
    "$GRANTIVA" run --device "$serial" --no-build --flow .maestro/11-slow.yaml --report-dir "$d/report" > "$d/stdout.log" 2> "$d/stderr.log" &
  fi
  local pid=$!
  printf 'owned-shell-pid=%s\n' "$pid" >> "$d/commands.txt"
  local observed=0 attempt
  for attempt in $(seq 1 80); do
    if [ -s "$state" ]; then
      w=$(adb -s "$serial" shell settings get global window_animation_scale 2>/dev/null | tr -d '\r')
      t=$(adb -s "$serial" shell settings get global transition_animation_scale 2>/dev/null | tr -d '\r')
      a=$(adb -s "$serial" shell settings get global animator_duration_scale 2>/dev/null | tr -d '\r')
      demo=$(adb -s "$serial" shell settings get global sysui_demo_allowed 2>/dev/null | tr -d '\r')
      if [ "$w" = 0 ] && [ "$t" = 0 ] && [ "$a" = 0 ] && [ "$demo" = 1 ]; then
        cp "$state" "$d/settings-state-during.json"
        snapshot_settings during "$name"
        observed=1
        break
      fi
    fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  wait "$pid"
  local rc=$?
  printf 'rc=%s observed-state=%s state-path=%s\n' "$rc" "$observed" "$state" >> "$d/commands.txt"
  snapshot_settings after "$name"
  if [ -e "$state" ]; then
    cp "$state" "$d/unexpected-state-after-run.json"
    return 1
  fi
  [ "$rc" -eq 0 ] && [ "$observed" -eq 1 ]
}

serial=$(owned_serial) || exit 3
printf '%s\n' "$serial" > "$base/input/owned-serial.txt"
adb devices -l > "$base/input/adb-devices.txt"
failures=0
run_observed AND-065-067 '' || failures=$((failures + 1))
run_observed AND-145 --allow-device-settings || failures=$((failures + 1))
adb forward --list > "$base/final-forwards.txt"
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
