#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/starting-session-contracts-rerun4"; [ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-starting-session-contracts-v4.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/starting-session-client-v4.py" "$base/input/client.py"
serial=""; while read -r s; do [ "$(adb -s "$s" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 3; [ -z "$serial" ] || exit 4; serial="$s"; done < <(adb devices|awk 'NR>1&&$2=="device"{print $1}'); [ -n "$serial" ] || exit 5
cd "$P" || exit 6
printf '# cwd=%s\n$ python3 -I %q %q %q %q\n' "$PWD" "$base/input/client.py" "$base/run" "$P" "$GRANTIVA" "$serial" > "$base/commands.txt"
python3 -I "$base/input/client.py" "$base/run" "$P" "$GRANTIVA" "$serial"; rc=$?
"$GRANTIVA" runner stop --json > "$base/final-cleanup.out" 2> "$base/final-cleanup.err" || true
printf 'client-rc=%s\n' "$rc" > "$base/summary.txt"
[ "$rc" -eq 0 ] && jq -e '.sawStarting == true' "$base/run/starting-observations.json" >/dev/null && jq -e '.state == "ready"' "$base/run/ready-observation.json" >/dev/null && jq -e 'all(.[]; .success == true)' "$base/run/ready-results.json" >/dev/null && grep -qx '0' "$base/run/first-detach-exit-before-stop.txt" && test ! -e .grantiva/session.json
