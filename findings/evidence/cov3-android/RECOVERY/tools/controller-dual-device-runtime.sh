#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/dual-device-runtime-exact-rerun1"; name=cov3-android-2
[ ! -e "$base" ] || { echo refusing-overwrite >&2; exit 2; }
mkdir -p "$base/input" "$base/p1/.maestro" "$base/p2/.maestro"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-dual-device-runtime.sh" "$base/input/controller-script.sh"
apk="$E/B2-K25-full-exact-rerun1/input/app-free-debug.apk"; test -s "$apk" || exit 3; cp "$apk" "$base/input/app.apk"; apk="$base/input/app.apk"
cp "$P/.maestro/01-browse.yaml" "$base/p1/.maestro/01.yaml"; cp "$P/.maestro/05-category.yaml" "$base/p2/.maestro/05.yaml"
[ ! -d "$HOME/.android/avd/$name.avd" ] || { echo secondary-exists >&2; exit 4; }
cleaned=0
primary_started=0
secondary_started=0
cleanup_secondary() {
  if [ "$primary_started" -eq 1 ]; then (cd "$base/p1" && "$GRANTIVA" runner stop > "$base/trap-stop-primary.out" 2> "$base/trap-stop-primary.err") || true; fi
  if [ "$secondary_started" -eq 1 ]; then (cd "$base/p2" && "$GRANTIVA" runner stop > "$base/trap-stop-secondary.out" 2> "$base/trap-stop-secondary.err") || true; fi
  [ -f "$base/owned-secondary" ] || return 0
  [ "$cleaned" -eq 0 ] || return 0
  s=""
  while read -r c; do [ "$(adb -s "$c" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && s="$c"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}')
  if [ -n "$s" ]; then "$GRANTIVA" emulator teardown --serial "$s" > "$base/trap-teardown.out" 2> "$base/trap-teardown.err" || true; fi
  if [ -n "$s" ]; then for i in $(seq 1 30); do adb -s "$s" get-state >/dev/null 2>&1 || break; sleep 1; done; fi
  if avdmanager list avd -c | grep -Fxq "$name"; then "$GRANTIVA" emulator delete --name "$name" > "$base/trap-delete.out" 2> "$base/trap-delete.err" || true; fi
}
trap cleanup_secondary EXIT
primary=""; while read -r s; do avd=$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1); [ "$avd" = cov3-android ] || exit 5; primary="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}')
[ -n "$primary" ] || exit 6
cat > "$base/p1/grantiva-android.yml" <<Y
platform: android
application_id: com.kylebrowning.landmarks
emulator: cov3-android
flows: [.maestro/01.yaml]
Y
cat > "$base/p2/grantiva-android.yml" <<Y
platform: android
application_id: com.kylebrowning.landmarks
emulator: $name
flows: [.maestro/05.yaml]
Y
run(){ n=$1; shift; mkdir -p "$base/$n"; { printf '# cwd=%s\n$' "$PWD"; printf ' %q' "$@"; echo; } > "$base/$n/commands.txt"; "$@" >"$base/$n/stdout.log" 2>"$base/$n/stderr.log"; rc=$?; echo rc=$rc >>"$base/$n/commands.txt"; return $rc; }
cd "$base/p2"; run create "$GRANTIVA" emulator ensure --name "$name" --no-boot || exit 7; touch "$base/owned-secondary"
run boot "$GRANTIVA" emulator ensure --name "$name" --headless || exit 8
secondary=""; for i in $(seq 1 60); do while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = "$name" ] && secondary="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$secondary" ] && break; sleep 1; done
[ -n "$secondary" ] || exit 9; echo "$primary $secondary" > "$base/input/serials.txt"
adb -s "$secondary" install -r "$apk" > "$base/input/install-secondary.out" 2> "$base/input/install-secondary.err" || exit 10
# AND-062 genuine simultaneous runs.
printf '# cwd=%s\n$ %q run --device %q --no-build --flow .maestro/01.yaml --report-dir %q\n' "$base/p1" "$GRANTIVA" "$primary" "$base/AND-062-primary/report" > "$base/AND-062-primary.commands.txt"
printf '# cwd=%s\n$ %q run --device %q --no-build --flow .maestro/05.yaml --report-dir %q\n' "$base/p2" "$GRANTIVA" "$secondary" "$base/AND-062-secondary/report" > "$base/AND-062-secondary.commands.txt"
cd "$base/p1"; "$GRANTIVA" run --device "$primary" --no-build --flow .maestro/01.yaml --report-dir "$base/AND-062-primary/report" > "$base/AND-062-primary.out" 2> "$base/AND-062-primary.err" & p1=$!
cd "$base/p2"; "$GRANTIVA" run --device "$secondary" --no-build --flow .maestro/05.yaml --report-dir "$base/AND-062-secondary/report" > "$base/AND-062-secondary.out" 2> "$base/AND-062-secondary.err" & p2=$!
wait "$p1"; r1=$?; wait "$p2"; r2=$?; printf 'pids=%s,%s rc=%s,%s\n' "$p1" "$p2" "$r1" "$r2" > "$base/AND-062-commands.txt"
# Two detached sessions; newest default hierarchy and explicit older hierarchy.
cd "$base/p1"; run start-primary "$GRANTIVA" runner start --device "$primary" --detach --json || exit 11; primary_started=1
cd "$base/p2"; run start-secondary "$GRANTIVA" runner start --device "$secondary" --detach --json || exit 12; secondary_started=1
mkdir -p "$base/query/readiness"; cd "$base/query"
ready=0; for i in $(seq 1 20); do "$GRANTIVA" hierarchy --udid "$secondary" > "$base/query/readiness/$i.out" 2> "$base/query/readiness/$i.err" && grep -q Landmarks "$base/query/readiness/$i.out" && { ready=1; break; }; sleep 1; done; [ "$ready" -eq 1 ] || exit 16
ready=0; for i in $(seq 1 20); do "$GRANTIVA" hierarchy --udid "$primary" > "$base/query/readiness/primary-$i.out" 2> "$base/query/readiness/primary-$i.err" && grep -q Landmarks "$base/query/readiness/primary-$i.out" && { ready=1; break; }; sleep 1; done; [ "$ready" -eq 1 ] || exit 18
run AND-052 "$GRANTIVA" hierarchy || true; run AND-056 "$GRANTIVA" hierarchy --udid "$primary" || true
# With live sessions, hierarchy's extra adb forward exists only for the command.
adb forward --list > "$base/AND-057-before.txt"; run AND-057 "$GRANTIVA" hierarchy --udid "$primary" || true; adb forward --list > "$base/AND-057-after.txt"
cd "$base/p1"; if run stop-primary "$GRANTIVA" runner stop; then primary_started=0; fi
cd "$base/p2"; if run stop-secondary "$GRANTIVA" runner stop; then secondary_started=0; fi
# Orphan secondary forward must survive a primary run/cleanup.
adb -s "$secondary" forward --no-rebind tcp:28123 tcp:6790 > "$base/AND-064-forward.out" 2> "$base/AND-064-forward.err" || exit 17
adb forward --list > "$base/AND-064-before.txt"
cd "$base/p1"; run AND-064 "$GRANTIVA" run --device "$primary" --no-build --flow .maestro/01.yaml --report-dir "$base/AND-064/report" || true
adb forward --list > "$base/AND-064-after.txt"; adb -s "$secondary" forward --remove tcp:28123
# Delete only the secondary created here.
cd "$base/p2"; run teardown-secondary "$GRANTIVA" emulator teardown --serial "$secondary" || exit 13
for i in $(seq 1 30); do adb -s "$secondary" get-state >/dev/null 2>&1 || break; sleep 1; done
[ -f "$base/owned-secondary" ] || exit 14; run delete-secondary "$GRANTIVA" emulator delete --name "$name" || exit 15
cleaned=1
printf 'run-rc=%s,%s secondary=%s\n' "$r1" "$r2" "$secondary" > "$base/summary.txt"
