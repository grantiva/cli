#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/B2-K87-ten-runner-cycles-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project" "$d/cycles" "$d/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-runner-ten-cycle-cleanup-v2.sh" "$d/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$d/project/grantiva-android.yml"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"
[ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"
[ "$avd" = cov3-android ] || { echo "owned AVD mismatch: $avd" >&2; exit 5; }
cd "$d/project"
[ ! -e .grantiva/session.json ] || { echo 'preexisting scratch session' >&2; exit 6; }
"$adb_bin" forward --list > "$d/forwards-before.txt"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print 2>/dev/null | sort > "$d/global-files-before.txt"
: > "$d/commands.txt"; : > "$d/pids.txt"; failures=0
cleanup() { "$GRANTIVA" runner stop --json > "$d/trap-stop.json" 2> "$d/trap-stop.err" || true; }
trap cleanup EXIT
for i in $(seq 1 10); do
 c="$d/cycles/$i"; mkdir -p "$c"
 printf '# cycle %s cwd=%s\n$ %s runner start --platform android --device %s --application-id com.kylebrowning.landmarks --detach --json\n$ %s runner stop --json\n' "$i" "$d/project" "$GRANTIVA" "$serial" "$GRANTIVA" >> "$d/commands.txt"
 "$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json > "$c/start.json" 2> "$c/start.err"; src=$?
 printf '%s\n' "$src" > "$c/start.exit.txt"
 if [ "$src" -ne 0 ]; then failures=$((failures+1)); break; fi
 pid="$(jq -r '.pid' "$c/start.json")"; port="$(jq -r '.port' "$c/start.json")"
 case "$pid:$port" in *[!0-9:]*|:*) echo "invalid pid/port $pid:$port" >&2; failures=$((failures+1)); break;; esac
 printf '%s\n' "$pid" >> "$d/pids.txt"
 cp .grantiva/session.json "$c/session.json"
 hrc=1
 for hpoll in $(seq 1 20); do
  "$GRANTIVA" runner dump-hierarchy --udid "$serial" --format json > "$c/hierarchy-$hpoll.json" 2> "$c/hierarchy-$hpoll.err"; hrc=$?
  if [ "$hrc" -eq 0 ] && grep -q 'Golden Gate Bridge' "$c/hierarchy-$hpoll.json"; then cp "$c/hierarchy-$hpoll.json" "$c/hierarchy.json"; break; fi
  sleep 0.25
 done
 "$GRANTIVA" runner stop --json > "$c/stop.json" 2> "$c/stop.err"; trc=$?
 printf '%s\n' "$trc" > "$c/stop.exit.txt"
 dead=0
 for poll in $(seq 1 30); do
  if ! kill -0 "$pid" 2>/dev/null; then dead=1; break; fi
  sleep 0.1
 done
 find /tmp/grantiva-sessions -maxdepth 1 -type f \( -name "$pid.owner.json" -o -name "$pid-*.grantiva" -o -name "$pid-*.stop" \) -print 2>/dev/null | sort > "$c/pid-global-files-after.txt"
 printf 'start=%s hierarchy=%s stop=%s pid=%s port=%s dead=%s session_absent=%s pid_global_files=%s\n' "$src" "$hrc" "$trc" "$pid" "$port" "$dead" "$([ ! -e .grantiva/session.json ] && echo true || echo false)" "$(wc -l < "$c/pid-global-files-after.txt" | tr -d ' ')" > "$c/summary.txt"
 if [ "$hrc" -ne 0 ] || [ "$trc" -ne 0 ] || [ "$dead" -ne 1 ] || [ -e .grantiva/session.json ] || [ -s "$c/pid-global-files-after.txt" ]; then failures=$((failures+1)); break; fi
done
trap - EXIT
"$adb_bin" forward --list > "$d/forwards-after.txt"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print 2>/dev/null | sort > "$d/global-files-after.txt"
cp "$W/../release-main/Tests/GrantivaCoreTests/KeepAliveSessionStoreTests.swift" "$d/source/KeepAliveSessionStoreTests.swift"
git -C "$W/../release-main" rev-parse HEAD > "$d/source/cli-head.txt"
sort "$d/pids.txt" | uniq > "$d/pids-unique.txt"
count="$(wc -l < "$d/pids.txt" | tr -d ' ')"; unique="$(wc -l < "$d/pids-unique.txt" | tr -d ' ')"
printf 'cycles=%s unique_pids=%s failures=%s session_absent=%s forwards_same=%s\n' "$count" "$unique" "$failures" "$([ ! -e .grantiva/session.json ] && echo true || echo false)" "$(cmp -s "$d/forwards-before.txt" "$d/forwards-after.txt" && echo true || echo false)" > "$d/summary.txt"
test "$count" -eq 10 && test "$unique" -eq 10 && test "$failures" -eq 0 && test ! -e .grantiva/session.json && cmp -s "$d/forwards-before.txt" "$d/forwards-after.txt"
