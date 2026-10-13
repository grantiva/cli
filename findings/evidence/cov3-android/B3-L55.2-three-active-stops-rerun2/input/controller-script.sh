#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B3-L55.2-three-active-stops-rerun2"
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-b3-l55-android-three-stops-v2.sh" "$base/input/controller-script.sh"
cp "$P/.maestro/coverage/18-long-wait.yaml" "$base/input/18-long-wait.yaml"
serial=""
while read -r s; do
  [ "$(adb -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 3
  [ -z "$serial" ] || exit 4
  serial="$s"
done < <(adb devices | awk 'NR>1&&$2=="device"{print $1}')
[ -n "$serial" ] || exit 5
cd "$P" || exit 6
rp=""
cleanup() {
  cd "$P" 2>/dev/null || true
  if [ -n "$rp" ] && kill -0 "$rp" 2>/dev/null; then
    "$GRANTIVA" runner stop --json >/dev/null 2>&1 || kill -INT "$rp" 2>/dev/null || true
    wait "$rp" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM
failures=0
for i in 1 2 3; do
  d="$base/cycle-$i"
  mkdir -p "$d"
  ready="$d/ready.json"
  printf '# cwd=%s\n$ %q run --platform android --device %q --no-build --keep-alive --flow .maestro/coverage/18-long-wait.yaml --ready-file %q --report-dir %q\n' "$PWD" "$GRANTIVA" "$serial" "$ready" "$d/report" > "$d/commands.txt"
  "$GRANTIVA" run --platform android --device "$serial" --no-build --keep-alive --flow .maestro/coverage/18-long-wait.yaml --ready-file "$ready" --report-dir "$d/report" > "$d/run.out" 2> "$d/run.err" &
  rp=$!
  echo "owned-run-pid=$rp" >> "$d/commands.txt"
  seen=0
  for attempt in $(seq 1 120); do
    owner=""
    for candidate in /tmp/grantiva-sessions/*.owner.json; do
      [ -f "$candidate" ] || continue
      if [ "$(jq -r '.projectDirectory // empty' "$candidate" 2>/dev/null)" = "$P" ] && [ "$(jq -r '.grantivaPid // empty' "$candidate" 2>/dev/null)" = "$rp" ] && [ "$(jq -r '.platform // empty' "$candidate" 2>/dev/null)" = android ] && [ "$(jq -r '.udid // empty' "$candidate" 2>/dev/null)" = "$serial" ]; then owner="$candidate"; break; fi
    done
    if [ -n "$owner" ] && kill -0 "$rp" 2>/dev/null && grep -q '\[1/1\] 18-long-wait' "$d/run.err" && grep -q 'launchApp' "$d/run.err"; then
      cp "$owner" "$d/owner-while-running.json"
      if [ -e "$ready" ]; then cp "$ready" "$d/unexpected-ready-while-running.json"; else printf 'absent while active flow stream and owned runner were live\n' > "$d/ready-absent-while-running.txt"; fi
      seen=1
      break
    fi
    sleep 0.1
  done
  if [ "$seen" -ne 1 ]; then
    echo 'did-not-observe-owned-active-flow' > "$d/harness-error.txt"
    cleanup
    rp=""
    failures=$((failures+1))
    continue
  fi
  printf '$ %q runner stop\n' "$GRANTIVA" >> "$d/commands.txt"
  "$GRANTIVA" runner stop > "$d/stop.out" 2> "$d/stop.err"
  stoprc=$?
  wait "$rp"
  runrc=$?
  rp=""
  cp "$ready" "$d/ready-after-stop.json"
  find /tmp/grantiva-sessions -maxdepth 1 -type f -print | LC_ALL=C sort > "$d/session-files-after.txt"
  adb forward --list > "$d/forwards-after.txt"
  printf 'stop=%s run=%s ready=%s\n' "$stoprc" "$runrc" "$(jq -r '.status' "$ready")" > "$d/summary.txt"
  [ "$stoprc" -eq 0 ] || failures=$((failures+1))
  [ "$runrc" -eq 130 ] || failures=$((failures+1))
  [ "$(jq -r '.status' "$ready")" = interrupted ] || failures=$((failures+1))
  test ! -e .grantiva/session.json || failures=$((failures+1))
done
printf 'failures=%s serial=%s\n' "$failures" "$serial" > "$base/summary.txt"
[ "$failures" -eq 0 ]
