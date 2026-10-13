#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/secondary-shutdown-contracts-exact-rerun2"; name=cov3-android-2
[ ! -e "$base" ] || exit 2; [ ! -d "$HOME/.android/avd/$name.avd" ] || exit 3
mkdir -p "$base/input" "$base/project/flow-directory"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-secondary-shutdown-contracts-rerun2.sh" "$base/input/controller-script.sh"
cat > "$base/project/grantiva-android.yml" <<Y
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
flows: [configured-missing.yaml]
Y
owned=0; cleaned=0
cleanup(){ [ $owned -eq 1 ] || return 0; [ $cleaned -eq 0 ] || return 0; s=""; while read -r c; do [ "$(adb -s "$c" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && s="$c"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); if [ -n "$s" ]; then "$GRANTIVA" emulator teardown --serial "$s" >"$base/trap-teardown.out" 2>"$base/trap-teardown.err" || true; for i in $(seq 1 30); do adb -s "$s" get-state >/dev/null 2>&1 || break; sleep 1; done; fi; if avdmanager list avd -c|grep -Fxq "$name"; then "$GRANTIVA" emulator delete --name "$name" >"$base/trap-delete.out" 2>"$base/trap-delete.err" || true; fi; }
trap cleanup EXIT
run(){ n=$1; expect=$2; shift 2; mkdir -p "$base/$n"; { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } >"$base/$n/commands.txt"; t0=$(python3 -I -c 'import time;print(time.monotonic())'); "$@" >"$base/$n/stdout.log" 2>"$base/$n/stderr.log"; rc=$?; t1=$(python3 -I -c 'import time;print(time.monotonic())'); python3 -I -c 'import sys;print(round(float(sys.argv[2])-float(sys.argv[1]),3))' "$t0" "$t1" >"$base/$n/elapsed.txt"; echo rc=$rc >>"$base/$n/commands.txt"; if [ "$expect" = zero ]; then [ $rc -eq 0 ]; else [ $rc -ne 0 ]; fi; }
cd "$base/project"; failures=0
run new-shutdown zero "$GRANTIVA" emulator ensure --name "$name" --no-boot || exit 4; owned=1
adb devices -l > "$base/K44-adb-before.txt"
run K44-missing-build nonzero "$GRANTIVA" run --emulator "$name" --flow missing.yaml || failures=$((failures+1))
run K44-missing-nobuild nonzero "$GRANTIVA" run --emulator "$name" --no-build --flow missing.yaml || failures=$((failures+1))
run K44-directory nonzero "$GRANTIVA" run --emulator "$name" --no-build --flow flow-directory || failures=$((failures+1))
run K44-configured nonzero "$GRANTIVA" run --emulator "$name" --no-build || failures=$((failures+1))
adb devices -l > "$base/K44-adb-after.txt"
for c in K44-missing-build K44-missing-nobuild K44-directory K44-configured; do find "$base/$c" -type f -name 'failure-*.png' -print > "$base/$c/failure-screenshots.txt"; done
run boot-plain zero "$GRANTIVA" emulator ensure --name "$name" || exit 5
secondary=$(cat "$base/boot-plain/stdout.log"|tr -d '\r\n'); case "$secondary" in emulator-*) ;; *) exit 6;; esac
[ "$(adb -s "$secondary" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] || exit 7
run running-noboot-text zero "$GRANTIVA" emulator ensure --name "$name" --no-boot || failures=$((failures+1))
run running-noboot-json zero "$GRANTIVA" emulator ensure --name "$name" --no-boot --json || failures=$((failures+1))
run teardown zero "$GRANTIVA" emulator teardown --serial "$secondary" || exit 8
for i in $(seq 1 30); do adb -s "$secondary" get-state >/dev/null 2>&1 || break; sleep 1; done
run stopped-noboot-text zero "$GRANTIVA" emulator ensure --name "$name" --no-boot || failures=$((failures+1))
run stopped-noboot-json zero "$GRANTIVA" emulator ensure --name "$name" --no-boot --json || failures=$((failures+1))
adb devices -l > "$base/stopped-adb.txt"
run delete-json zero "$GRANTIVA" emulator delete --name "$name" --json || exit 9
# X-014: actual fresh boot in plain mode, then reused JSON.
run fresh-boot-plain zero "$GRANTIVA" emulator ensure --name "$name" --headless || exit 10
fresh1=$(cat "$base/fresh-boot-plain/stdout.log" | tr -d '\r\n'); case "$fresh1" in emulator-*) ;; *) exit 11;; esac
run fresh-reuse-json zero "$GRANTIVA" emulator ensure --name "$name" --json || exit 12
run fresh1-teardown zero "$GRANTIVA" emulator teardown --serial "$fresh1" || exit 13
for i in $(seq 1 30); do adb -s "$fresh1" get-state >/dev/null 2>&1 || break; sleep 1; done
run fresh1-delete zero "$GRANTIVA" emulator delete --name "$name" || exit 14
# X-014 complementary fresh boot in JSON mode, then reused plain.
run fresh-boot-json zero "$GRANTIVA" emulator ensure --name "$name" --headless --json || exit 15
fresh2=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["serial"])' "$base/fresh-boot-json/stdout.log")
case "$fresh2" in emulator-*) ;; *) exit 16;; esac
run fresh-reuse-plain zero "$GRANTIVA" emulator ensure --name "$name" || exit 17
run fresh2-teardown zero "$GRANTIVA" emulator teardown --serial "$fresh2" || exit 18
for i in $(seq 1 30); do adb -s "$fresh2" get-state >/dev/null 2>&1 || break; sleep 1; done
run fresh2-delete zero "$GRANTIVA" emulator delete --name "$name" || exit 19
avdmanager list avd -c > "$base/avds-final.txt" 2> "$base/avds-final.err"
grep -Fxq "$name" "$base/avds-final.txt" && exit 20
cleaned=1
printf 'aggregate-failures=%s initial=%s fresh1=%s fresh2=%s\n' "$failures" "$secondary" "$fresh1" "$fresh2" > "$base/summary.txt"; exit "$failures"
