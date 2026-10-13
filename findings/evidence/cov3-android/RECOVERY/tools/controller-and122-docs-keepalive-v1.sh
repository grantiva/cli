#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
base="$E/AND-122-docs-keepalive-examples-rerun1"; serial=emulator-5554
[ ! -e "$base" ] || exit 2
mkdir -p "$base/input" "$base/project/.maestro" "$base/run"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/controller-and122-docs-keepalive-v1.sh" "$base/input/controller-script.sh"
cp "$W/findings/evidence/cov3-android/RECOVERY/tools/and122-docs-keepalive-client-v1.py" "$base/input/client.py"
cp "$P/.maestro/01-browse.yaml" "$base/project/.maestro/01-browse.yaml"
for item in app gradle build.gradle.kts gradle.properties gradlew settings.gradle.kts; do ln -s "$P/$item" "$base/project/$item"; done
cat > "$base/project/grantiva-android.yml" <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: cov3-android
flows:
  - .maestro/01-browse.yaml
YAML
cp "$base/project/grantiva-android.yml" "$base/input/grantiva-android.yml"
sed -n '138,147p' /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/docs/android.md > "$base/input/docs-lines.txt"
adb -s "$serial" get-state > "$base/adb-before.txt" || exit 3
[ "$(adb -s "$serial" emu avd name 2>/dev/null|tr -d '\r'|head -1)" = cov3-android ] || exit 4
python3 -I -c 'import os,sys,json; x=os.getloadavg()[0]; print(json.dumps({"load1":x})); sys.exit(0 if x < 20 else 1)' > "$base/load-before.json" || exit 5
(cd "$base/project" && python3 -I "$base/input/client.py" "$base/run" "$base/project" "$GRANTIVA")
