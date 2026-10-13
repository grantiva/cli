#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/HIERARCHY-session-exact"; mkdir -p "$d/input" "$d/report"
cp .maestro/01-browse.yaml "$d/input/"
rm -f "$d/ready.json"
printf '# cwd=%s\n$ %s run --device emulator-5554 --no-build --keep-alive --flow .maestro/01-browse.yaml --ready-file %s --report-dir %s\n' "$P" "$GRANTIVA" "$d/ready.json" "$d/report" > "$d/commands.txt"
"$GRANTIVA" run --device emulator-5554 --no-build --keep-alive --flow .maestro/01-browse.yaml --ready-file "$d/ready.json" --report-dir "$d/report" > "$d/keepalive.out" 2> "$d/keepalive.err" & kp=$!
ready=0
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if [ -f "$d/ready.json" ]; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then "$GRANTIVA" runner stop --json > "$d/early-stop.out" 2> "$d/early-stop.err"; wait "$kp"; exit 1; fi
cat "$d/ready.json" > "$d/ready-observed.json"
kill -0 "$kp"; echo "keepalive-process-alive-after-ready=$?" >> "$d/commands.txt"
adb forward --list > "$d/forwards-before.txt"
rec AND-061-exact "$GRANTIVA hierarchy --timeout 10; echo exit=\$?"
rec AND-053-exact "$GRANTIVA hierarchy; echo exit=\$?"
rec AND-054-exact "$GRANTIVA hierarchy --format json; echo exit=\$?"
rec AND-055-exact "$GRANTIVA hierarchy --json; echo exit=\$?"
adb forward --list > "$d/forwards-after-hierarchy.txt"
"$GRANTIVA" runner stop --json > "$d/stop.out" 2> "$d/stop.err"; src=$?
wait "$kp"; krc=$?
printf '$ grantiva runner stop --json\nstop-rc=%s keepalive-rc=%s\n' "$src" "$krc" >> "$d/commands.txt"
test ! -e .grantiva/session.json
