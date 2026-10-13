#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/B2-K88-runner-start-pty-rerun1"
serial=emulator-5554
[ ! -e "$base" ] || { echo refusing-overwrite >&2; exit 2; }
mkdir -p "$base/input" "$base/project" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-k88-runner-start-pty-v1.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/k88-runner-start-pty-client-v1.py" "$base/input/client.py"
cp "$P/grantiva-android.yml" "$base/project/grantiva-android.yml"
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | head -1)" = cov3-android ] || exit 4
[ ! -e "$base/project/.grantiva/session.json" ] || exit 5
(cd "$base/project" && python3 -I "$base/input/client.py" "$base/run" "$base/project" "$GRANTIVA" "$serial")
rc=$?
if [ "$rc" -ne 0 ]; then
  (cd "$base/project" && "$GRANTIVA" runner stop --json) > "$base/cleanup.json" 2> "$base/cleanup.err" || true
fi
exit "$rc"
