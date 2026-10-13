#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-083-exact-rerun2"
if [ -e "$base" ]; then echo "refusing overwrite: $base" >&2; exit 2; fi
mkdir -p "$base/input" "$base/project"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and083-config-precedence-rerun.sh" "$base/input/controller-script.sh"
sed -e 's/^application_id:.*/application_id: configured.sentinel/' -e 's/^emulator:.*/emulator: configured-sentinel-do-not-create/' "$P/grantiva-android.yml" > "$base/project/grantiva-android.yml"
cd "$base/project"
if [ -e .grantiva/session.json ]; then echo 'existing session requires review' >&2; exit 3; fi
cp grantiva-android.yml "$base/input/grantiva-android.yml"
grep -q '^application_id: configured.sentinel$' "$base/input/grantiva-android.yml" || exit 4
grep -q '^emulator: configured-sentinel-do-not-create$' "$base/input/grantiva-android.yml" || exit 5
printf '# cwd=%s\n$ %s runner start --application-id x.y --emulator cov3-android --detach --json\n' "$PWD" "$GRANTIVA" > "$base/commands.txt"
"$GRANTIVA" runner start --application-id x.y --emulator cov3-android --detach --json > "$base/start.json" 2> "$base/start.err"; src=$?
printf 'start-rc=%s\n' "$src" >> "$base/commands.txt"
if [ "$src" -ne 0 ] || [ ! -f .grantiva/session.json ]; then exit 6; fi
cp .grantiva/session.json "$base/session.json"
python3 -I -c 'import json,sys; d=json.load(open(".grantiva/session.json")); sys.exit(0 if d.get("applicationId")=="x.y" and d.get("platform")=="android" and d.get("serial","").startswith("emulator-") else 1)' || { "$GRANTIVA" runner stop --json > "$base/cleanup.json" 2> "$base/cleanup.err"; exit 7; }
printf '$ %s runner stop --json\n' "$GRANTIVA" >> "$base/commands.txt"
"$GRANTIVA" runner stop --json > "$base/stop.json" 2> "$base/stop.err"; xrc=$?
printf 'stop-rc=%s\n' "$xrc" >> "$base/commands.txt"
[ "$xrc" -eq 0 ] && [ ! -e .grantiva/session.json ]
