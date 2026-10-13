#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/build-install-contracts-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/load"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-build-install-contracts.sh"
cp "$script_path" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config-at-start.yml"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
apk="$P/app/build/outputs/apk/free/debug/app-free-debug.apk"
test -s "$apk" || { echo "missing frozen freeDebug APK: $apk" >&2; exit 3; }
cp "$apk" "$base/input/app-free-debug.apk"
shasum -a 256 "$base/input/app-free-debug.apk" > "$base/input/app-free-debug.apk.sha256"

had_shared=0
if [ -e "$P/grantiva.yml" ]; then
  had_shared=1
  cp "$P/grantiva.yml" "$base/input/grantiva.yml-at-start"
fi
restore_inputs() {
  cp "$base/input/config-at-start.yml" "$P/grantiva-android.yml"
  if [ "$had_shared" -eq 1 ]; then
    cp "$base/input/grantiva.yml-at-start" "$P/grantiva.yml"
  elif [ -e "$P/grantiva.yml" ]; then
    python3 -I -c 'import os,sys; os.unlink(sys.argv[1])' "$P/grantiva.yml"
  fi
}
trap restore_inputs EXIT
cd "$P"

owned_serial() {
  local serial avd found=""
  while read -r serial; do
    [ -z "$serial" ] && continue
    avd=$(adb -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)
    if [ "$avd" = cov3-android ]; then
      [ -z "$found" ] || { echo "multiple cov3-android serials" >&2; return 1; }
      found="$serial"
    else
      echo "unexpected attached Android device $serial ($avd)" >&2
      return 1
    fi
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

wait_gradle_load() {
  local label="$1" load attempt
  for attempt in $(seq 1 120); do
    load=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')
    printf '%s attempt=%s one-minute-load=%s\n' "$(date -u +%FT%TZ)" "$attempt" "$load" >> "$base/load/$label.txt"
    python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 20 else 1)' "$load" && return 0
    sleep 5
  done
  echo "load stayed >=20 before $label" >&2
  return 1
}

run_case() {
  local name="$1"
  local expect="$2"
  shift 2
  mkdir -p "$base/$name"
  uptime > "$base/$name/uptime-before.txt"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; printf '\n'; } > "$base/$name/commands.txt"
  "$@" > "$base/$name/stdout.log" 2> "$base/$name/stderr.log"
  local rc=$?
  uptime > "$base/$name/uptime-after.txt"
  printf 'rc=%s expected=%s\n' "$rc" "$expect" >> "$base/$name/commands.txt"
  case "$expect" in zero) [ "$rc" -eq 0 ];; nonzero) [ "$rc" -ne 0 ];; any) return 0;; esac
}

failures=0
serial=$(owned_serial) || exit 4
printf '%s\n' "$serial" > "$base/input/owned-serial.txt"
adb devices -l > "$base/input/adb-devices.txt"
adb -s "$serial" emu avd name > "$base/input/owned-avd-name.txt" 2>&1
adb -s "$serial" shell getprop ro.product.cpu.abi > "$base/input/device-abi.txt"

# AND-021 / B-A10.2: structured install result and --no-launch postcondition.
adb -s "$serial" shell am force-stop com.kylebrowning.landmarks
wait_gradle_load AND-021 || exit 20
run_case AND-021 zero "$GRANTIVA" build install --no-launch --json --device "$serial" || failures=$((failures + 1))
adb -s "$serial" shell pidof com.kylebrowning.landmarks > "$base/AND-021/pidof-after.txt" 2> "$base/AND-021/pidof-after.err" || true
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/AND-021/pm-path-after.txt" 2> "$base/AND-021/pm-path-after.err" || true

# AND-022/023: exact Gradle variants, with Gradle streams preserved by Grantiva.
wait_gradle_load AND-022 || exit 21
run_case AND-022 any "$GRANTIVA" build build --variant freeRelease || failures=$((failures + 1))
wait_gradle_load AND-023 || exit 22
run_case AND-023 zero "$GRANTIVA" build build --variant paidDebug || failures=$((failures + 1))

# AND-024/025 and B-A09: preserve complete text and JSON failure envelopes.
wait_gradle_load AND-024-text || exit 23
run_case AND-024-text nonzero "$GRANTIVA" build build --variant noSuchVariant || failures=$((failures + 1))
wait_gradle_load AND-024-json || exit 24
run_case AND-024-json nonzero "$GRANTIVA" build build --variant noSuchVariant --json || failures=$((failures + 1))
wait_gradle_load AND-025-app || exit 25
run_case AND-025-app zero "$GRANTIVA" build build --module app || failures=$((failures + 1))
wait_gradle_load AND-025-nosuch || exit 26
run_case AND-025-nosuch nonzero "$GRANTIVA" build build --module nosuch || failures=$((failures + 1))

# AND-028: frozen APK must bypass Gradle; preserve report and installed package metadata.
run_case AND-028 zero "$GRANTIVA" run --device "$serial" --app-file "$base/input/app-free-debug.apk" --flow .maestro/01-browse.yaml --report-dir "$base/AND-028/report" || failures=$((failures + 1))
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/AND-028/pm-path.txt" 2> "$base/AND-028/pm-path.err" || true
if command -v apkanalyzer >/dev/null 2>&1; then
  apkanalyzer manifest application-id "$base/input/app-free-debug.apk" > "$base/AND-028/apkanalyzer-application-id.txt" 2> "$base/AND-028/apkanalyzer.err" || failures=$((failures + 1))
else
  echo apkanalyzer-not-found > "$base/AND-028/apkanalyzer.err"
  failures=$((failures + 1))
fi

# AND-144: both platform config names present; explicit platform must choose Android.
cat > "$P/grantiva.yml" <<'EOF'
platform: ios
scheme: SentinelDoNotUse
simulator: SentinelDoNotUse
EOF
cp "$P/grantiva.yml" "$base/AND-144-shared-config.yml"
cp "$P/grantiva-android.yml" "$base/AND-144-android-config.yml"
wait_gradle_load AND-144 || exit 27
run_case AND-144 zero "$GRANTIVA" build install --platform android --no-launch --device "$serial" || failures=$((failures + 1))
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/AND-144/pm-path-after.txt" 2> "$base/AND-144/pm-path-after.err" || true
python3 -I -c 'import os,sys; os.unlink(sys.argv[1])' "$P/grantiva.yml"

# B-A03: paidDebug's APK ID differs from config; resolver must use APK ID or fail clearly.
cp "$base/input/config-at-start.yml" "$P/grantiva-android.yml"
wait_gradle_load BA03-install || exit 28
run_case BA03-install any "$GRANTIVA" build install --variant paidDebug --no-launch --device "$serial" || failures=$((failures + 1))
adb -s "$serial" shell pm path com.kylebrowning.landmarks.paid > "$base/BA03-install/pm-path-paid.txt" 2> "$base/BA03-install/pm-path-paid.err" || true
wait_gradle_load BA03-run || exit 29
run_case BA03-run any "$GRANTIVA" run --variant paidDebug --device "$serial" --flow .maestro/01-browse.yaml --report-dir "$base/BA03-run/report" || failures=$((failures + 1))
adb -s "$serial" shell pm path com.kylebrowning.landmarks.paid > "$base/BA03-run/pm-path-paid.txt" 2> "$base/BA03-run/pm-path-paid.err" || true

# Restore the stock free app for subsequent groups.
cp "$base/input/config-at-start.yml" "$P/grantiva-android.yml"
run_case restore-free-app zero "$GRANTIVA" build install --no-launch --no-build --app-file "$base/input/app-free-debug.apk" --device "$serial" || failures=$((failures + 1))

adb devices -l > "$base/final-adb-devices.txt"
cp "$P/grantiva-android.yml" "$base/final-config.yml"
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
