#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh

base="$E/B2-K25-full-exact-rerun1"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k25-full-contract.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
cp "$P/.maestro/01-browse.yaml" "$base/input/01-browse.yaml"
apk="$E/build-install-contracts-exact-rerun1/input/app-free-debug.apk"
test -s "$apk" || { echo "missing frozen prior APK: $apk" >&2; exit 3; }
cp "$apk" "$base/input/app-free-debug.apk"
shasum -a 256 "$base/input/app-free-debug.apk" > "$base/input/app-free-debug.apk.sha256"
apk="$base/input/app-free-debug.apk"
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

run_case() {
  local name="$1"
  local expect="$2"
  shift 2
  mkdir -p "$base/$name"
  { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; printf '\n'; } > "$base/$name/commands.txt"
  uptime > "$base/$name/uptime-before.txt"
  "$@" > "$base/$name/stdout.log" 2> "$base/$name/stderr.log"
  local rc=$?
  uptime > "$base/$name/uptime-after.txt"
  printf 'rc=%s expected=%s\n' "$rc" "$expect" >> "$base/$name/commands.txt"
  case "$expect" in zero) [ "$rc" -eq 0 ];; nonzero) [ "$rc" -ne 0 ];; any) return 0;; esac
}

uninstall_and_prove_absent() {
  local name="$1"
  mkdir -p "$base/$name"
  adb -s "$serial" uninstall com.kylebrowning.landmarks > "$base/$name/uninstall.out" 2> "$base/$name/uninstall.err" || true
  adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/$name/pm-before.txt" 2> "$base/$name/pm-before.err" || true
  [ ! -s "$base/$name/pm-before.txt" ] || { echo "package remains before $name" >&2; return 1; }
}

prove_installed() {
  local name="$1"
  adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/$name/pm-after.txt" 2> "$base/$name/pm-after.err" || true
  grep -q '^package:' "$base/$name/pm-after.txt"
}

serial=$(owned_serial) || exit 4
printf '%s\n' "$serial" > "$base/input/owned-serial.txt"
adb devices -l > "$base/input/adb-devices.txt"
for cmd in 'build install' run 'diff capture' 'ci run'; do
  set -- $cmd
  "$GRANTIVA" "$@" --help > "$base/input/help-${cmd// /-}.txt" 2> "$base/input/help-${cmd// /-}.err"
done

failures=0
uninstall_and_prove_absent pair-build-install || exit 5
run_case pair-build-install zero "$GRANTIVA" build install --no-launch --no-build --app-file "$apk" --device "$serial" || failures=$((failures + 1))
prove_installed pair-build-install || failures=$((failures + 1))

uninstall_and_prove_absent pair-run || exit 6
run_case pair-run zero "$GRANTIVA" run --no-build --app-file "$apk" --device "$serial" --flow .maestro/01-browse.yaml --report-dir "$base/pair-run/report" || failures=$((failures + 1))
prove_installed pair-run || failures=$((failures + 1))

uninstall_and_prove_absent pair-diff-capture || exit 7
run_case pair-diff-capture zero "$GRANTIVA" diff capture --no-build --app-file "$apk" --device "$serial" || failures=$((failures + 1))
prove_installed pair-diff-capture || failures=$((failures + 1))
if [ -d .grantiva/captures ]; then cp -R .grantiva/captures "$base/pair-diff-capture/captures"; else failures=$((failures + 1)); fi

uninstall_and_prove_absent pair-ci-run || exit 8
run_case pair-ci-run any "$GRANTIVA" ci run --no-build --app-file "$apk" --device "$serial" --flow .maestro/01-browse.yaml || failures=$((failures + 1))
prove_installed pair-ci-run || true

# Restore a known installed app, then prove --no-build alone skips installation wording.
adb -s "$serial" install -r "$apk" > "$base/input/restore-before-no-build.out" 2> "$base/input/restore-before-no-build.err" || exit 9
run_case no-build-alone zero "$GRANTIVA" build install --no-launch --no-build --device "$serial" || failures=$((failures + 1))
prove_installed no-build-alone || failures=$((failures + 1))

uninstall_and_prove_absent pair-json || exit 10
run_case pair-json zero "$GRANTIVA" build install --no-launch --no-build --app-file "$apk" --device "$serial" --json || failures=$((failures + 1))
prove_installed pair-json || failures=$((failures + 1))

adb devices -l > "$base/final-adb-devices.txt"
printf 'aggregate-failures=%s\n' "$failures" > "$base/summary.txt"
exit "$failures"
