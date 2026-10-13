#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/N2-05-B3L13-dead-runner-stop-json-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/input" "$d/project" "$d/source"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-dead-runner-stop-json-v2.sh" "$d/input/controller-script.sh"
cp "$P/grantiva-android.yml" "$d/project/grantiva-android.yml"
cp "$W/../release-main/Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift" "$d/source/RunnerLifecycleCommandTests.swift"
git -C "$W/../release-main" rev-parse HEAD > "$d/source/cli-head.txt"
adb_bin="/Users/kyle/Library/Android/sdk/platform-tools/adb"; [ -x "$adb_bin" ] || exit 3
serial="$("$adb_bin" devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1}')"
[ "$serial" = emulator-5554 ] || { echo "owned serial mismatch: $serial" >&2; exit 4; }
avd="$("$adb_bin" -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)"; [ "$avd" = cov3-android ] || exit 5
cd "$d/project"; [ ! -e .grantiva/session.json ] || exit 6
printf '# cwd=%s\n$ %s runner start --platform android --device %s --application-id com.kylebrowning.landmarks --detach --json\n$ kill -9 <verified row-owned runner pid>\n$ %s runner stop --json\n' "$d/project" "$GRANTIVA" "$serial" "$GRANTIVA" > "$d/commands.txt"
"$GRANTIVA" runner start --platform android --device "$serial" --application-id com.kylebrowning.landmarks --detach --json > "$d/start.json" 2> "$d/start.err"; src=$?
[ "$src" -eq 0 ] || exit 7
pid="$(jq -r '.pid' "$d/start.json")"; case "$pid" in ''|*[!0-9]*) exit 8;; esac
cp .grantiva/session.json "$d/session-before-kill.json"
jq -e --argjson p "$pid" --arg s "$serial" '.pid==$p and .platform=="android" and .serial==$s and .applicationId=="com.kylebrowning.landmarks" and .state=="ready"' "$d/session-before-kill.json" >/dev/null || exit 9
ps -p "$pid" -o pid=,ppid=,command= > "$d/process-before-kill.txt"
grep -q '/Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.13+android-drivers-2/grantiva-runner' "$d/process-before-kill.txt" || exit 10
kill -9 "$pid"
dead=0; for poll in $(seq 1 50); do if ! kill -0 "$pid" 2>/dev/null; then dead=1; break; fi; sleep 0.1; done
[ "$dead" -eq 1 ] || exit 11
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; trc=$?
find /tmp/grantiva-sessions -maxdepth 1 -type f \( -name "$pid.owner.json" -o -name "$pid-*.grantiva" -o -name "$pid-*.stop" \) -print 2>/dev/null | sort > "$d/pid-global-files-after.txt"
"$adb_bin" forward --list > "$d/forwards-after.txt"
printf 'start=%s pid=%s dead=%s stop=%s session_absent=%s pid_global_files=%s\n' "$src" "$pid" "$dead" "$trc" "$([ ! -e .grantiva/session.json ] && echo true || echo false)" "$(wc -l < "$d/pid-global-files-after.txt" | tr -d ' ')" > "$d/summary.txt"
test "$trc" -eq 0 && test ! -e .grantiva/session.json && test ! -s "$d/pid-global-files-after.txt" && jq -e --argjson p "$pid" '.status=="stopped" and .alreadyExited==true and .runnerPid==$p' "$d/stop.json" >/dev/null
