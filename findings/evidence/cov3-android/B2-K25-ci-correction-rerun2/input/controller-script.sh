#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K25-ci-correction-rerun2"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/ci"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k25-ci-correction.sh" "$base/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$base/input/config.yml"
apk="$E/B2-K25-full-exact-rerun1/input/app-free-debug.apk"
test -s "$apk" || exit 3
cp "$apk" "$base/input/app-free-debug.apk"
apk="$base/input/app-free-debug.apk"
serial=""
while read -r s; do
  [ -z "$s" ] && continue
  avd=$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)
  [ "$avd" = cov3-android ] || { echo "unexpected device $s ($avd)" >&2; exit 4; }
  [ -z "$serial" ] || exit 5
  serial="$s"
done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
[ -n "$serial" ] || exit 6
printf '%s\n' "$serial" > "$base/input/owned-serial.txt"
adb -s "$serial" uninstall com.kylebrowning.landmarks > "$base/ci/uninstall.out" 2> "$base/ci/uninstall.err" || true
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/ci/pm-before.txt" 2> "$base/ci/pm-before.err" || true
[ ! -s "$base/ci/pm-before.txt" ] || exit 7
cd "$P"
{ printf '# cwd=%s\n$ %q ci run --no-build --app-file %q --device %q\n' "$PWD" "$GRANTIVA" "$apk" "$serial"; } > "$base/ci/commands.txt"
"$GRANTIVA" ci run --no-build --app-file "$apk" --device "$serial" > "$base/ci/stdout.log" 2> "$base/ci/stderr.log"
rc=$?
printf 'rc=%s\n' "$rc" >> "$base/ci/commands.txt"
adb -s "$serial" shell pm path com.kylebrowning.landmarks > "$base/ci/pm-after.txt" 2> "$base/ci/pm-after.err" || true
printf 'ci-rc=%s package-after=%s\n' "$rc" "$(test -s "$base/ci/pm-after.txt" && echo yes || echo no)" > "$base/summary.txt"
# Restore app only if CI stopped before installation.
if [ ! -s "$base/ci/pm-after.txt" ]; then adb -s "$serial" install -r "$apk" > "$base/ci/restore.out" 2> "$base/ci/restore.err" || exit 8; fi
exit 0
