#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
d="$E/AND-118-exact-rerun1"
if [ -e "$d" ]; then echo "refusing overwrite: $d" >&2; exit 2; fi
mkdir -p "$d/project/.maestro" "$d/report" "$d/input"
script_path="$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and118-no-device-narration.sh"; cp "$script_path" "$d/input/controller-script.sh"
cp "$P/.maestro/01-browse.yaml" "$d/project/.maestro/"
cat > "$d/project/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
flows:
  - .maestro/01-browse.yaml
YAML
cd "$d/project"
printf '# No emulator in config and no --device/--emulator flag.\n# cwd=%s\n$ %s run --no-build --report-dir %s\n' "$PWD" "$GRANTIVA" "$d/report" > "$d/commands.txt"
"$GRANTIVA" run --no-build --report-dir "$d/report" > "$d/stdout.log" 2> "$d/stderr.log"; rc=$?
printf 'rc=%s\n' "$rc" >> "$d/commands.txt"
cp "$d/report/report.json" "$d/report-preserved.json"
test "$rc" -eq 0
