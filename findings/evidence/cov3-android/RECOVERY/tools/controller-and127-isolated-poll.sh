#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/AND-127-isolated-poll-rerun2"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/polls" "$d/input"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and127-isolated-poll.sh"; cp "$script_path" "$d/input/controller-script.sh"
printf '# Must run with no concurrent iOS/Android runner start.\n# cwd=%s\n$ %s runner start --device emulator-5554 --detach\n' "$P" "$GRANTIVA" > "$d/commands.txt"
python3 -I -c 'import time; print(time.time())' > "$d/start-epoch.txt"
"$GRANTIVA" runner start --device emulator-5554 --detach > "$d/start.out" 2> "$d/start.err"; src=$?
python3 -I -c 'import time; print(time.time())' > "$d/start-return-epoch.txt"
printf 'start-rc=%s\n' "$src" >> "$d/commands.txt"
cp .grantiva/session.json "$d/session-at-return.json"
ready=0
for i in $(seq 0 20); do
  python3 -I -c 'import time; print(time.time())' > "$d/polls/$i.epoch"
  "$GRANTIVA" runner dump-hierarchy --format tree > "$d/polls/$i.out" 2> "$d/polls/$i.err"; rc=$?
  printf 'poll=%s rc=%s landmarks=%s\n' "$i" "$rc" "$(grep -c Landmarks "$d/polls/$i.out")" >> "$d/polls/summary.txt"
  if [ "$rc" -eq 0 ] && grep -q Landmarks "$d/polls/$i.out"; then ready=1; break; fi
  sleep 0.5
done
"$GRANTIVA" runner stop --json > "$d/stop.json" 2> "$d/stop.err"; xrc=$?
printf '$ grantiva runner stop --json\nstop-rc=%s landmarks-seen=%s\n' "$xrc" "$ready" >> "$d/commands.txt"
adb forward --list > "$d/forwards-after.txt"
test "$src" -eq 0; test "$xrc" -eq 0
test ! -e .grantiva/session.json
