#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B-A07.1-B2-K88-logs-tty-sigint-rerun1"; serial=emulator-5554
if [ -e "$base" ]; then echo refusing-overwrite >&2; exit 2; fi
mkdir -p "$base/input" "$base/project/.maestro" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-ba071-k88-logs-tty-v1.sh" "$base/input/controller-script.sh"; cp "$W/findings/evidence/cov3-android/RECOVERY/tools/logs-tty-sigint-client-v1.py" "$base/input/client.py"; cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"; cp "$P/.maestro/11-slow.yaml" "$base/project/.maestro/11-slow.yaml"; cp "$P/.maestro/11-slow.yaml" "$base/input/11-slow.yaml"
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
(cd "$base/project" && python3 -I "$base/input/client.py" "$base/run" "$base/project" "$GRANTIVA" "$serial"); rc=$?
(cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/final-stop.json" 2> "$base/final-stop.err" || true
exit "$rc"
