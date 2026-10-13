#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/N2-05-B3L13-two-device-multisession-rerun1"; name=cov3-android-multisession-r3
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-multisession-two-device-v1.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/multisession-two-device-client-v1.py" "$base/input/client.py"
cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
cp "$P/app/build/outputs/apk/free/debug/app-free-debug.apk" "$base/input/app-free-debug.apk"
shasum -a 256 "$base/input/app-free-debug.apk" > "$base/input/app-free-debug.apk.sha256"
test -s "$base/input/app-free-debug.apk" || exit 3
avdmanager list avd -c | grep -Fxq "$name" && exit 4
if [ -f "$HOME/.grantiva/android/created-avds.json" ] && grep -Fq "$name" "$HOME/.grantiva/android/created-avds.json"; then exit 5; fi
[ "$(adb -s emulator-5554 emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 6
adb devices -l > "$base/adb-before.txt"; avdmanager list avd -c > "$base/avds-before.txt"
cleanup() {
  (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/trap-stop.out" 2> "$base/trap-stop.err" || true
  if [ -f "$base/secondary-serial.txt" ]; then
    s="$(cat "$base/secondary-serial.txt")"
    [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && "$GRANTIVA" emulator teardown --serial "$s" --force > "$base/trap-teardown.out" 2> "$base/trap-teardown.err" || true
  fi
  if [ -f "$base/ownership-established" ] && avdmanager list avd -c | grep -Fxq "$name"; then "$GRANTIVA" emulator delete --name "$name" --force --json > "$base/trap-delete.out" 2> "$base/trap-delete.err" || true; fi
}
trap cleanup EXIT
(cd "$base/project" && "$GRANTIVA" emulator ensure --name "$name" --headless) > "$base/ensure.out" 2> "$base/ensure.err"; erc=$?
printf '%s\n' "$erc" > "$base/ensure.exit.txt"; test "$erc" -eq 0 || exit 7
touch "$base/ownership-established"
secondary=''
for attempt in $(seq 1 90); do
  while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && secondary="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}')
  [ -n "$secondary" ] && break; sleep 1
done
[ -n "$secondary" ] || exit 8
printf '%s\n' "$secondary" > "$base/secondary-serial.txt"
(cd "$base/project" && "$GRANTIVA" build install --platform android --device "$secondary" --no-build --no-launch --app-file "$base/input/app-free-debug.apk") > "$base/install.out" 2> "$base/install.err"; irc=$?
printf '%s\n' "$irc" > "$base/install.exit.txt"; test "$irc" -eq 0 || exit 9
printf '# cwd=%s\n$ python3 -I %q %q %q %q emulator-5554 %q\n' "$base/project" "$base/input/client.py" "$base/run" "$base/project" "$GRANTIVA" "$secondary" > "$base/commands.txt"
python3 -I "$base/input/client.py" "$base/run" "$base/project" "$GRANTIVA" emulator-5554 "$secondary"; rc=$?
printf '%s\n' "$rc" > "$base/client.exit.txt"
test "$rc" -eq 0 || exit 10
cleanup
trap - EXIT
adb devices -l > "$base/adb-after.txt"; avdmanager list avd -c > "$base/avds-after.txt"
test ! -e "$base/project/.grantiva/session.json" && ! avdmanager list avd -c | grep -Fxq "$name"
