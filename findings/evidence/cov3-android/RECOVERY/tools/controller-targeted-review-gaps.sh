#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"

T=.maestro/coverage/cov3-targeted-review
mkdir -p "$T"
cat > "$T/and-202-text-map.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Lake Tahoe"
- assertVisible: "Lake Tahoe"
- back
- tapOn: {text: "Lake Tahoe"}
- assertVisible: "Lake Tahoe"
YAML
cat > "$T/and-210-double-first.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Profile"
- tapOn: "Gesture Lab"
- tapOn: "Gesture Taps"
- assertVisible: "Taps: 0"
- assertVisible: "Double taps: 0"
- doubleTapOn: {id: "gesture-pad"}
- assertVisible: "Double taps: 1"
- assertVisible: "Taps: 0"
YAML
cat > "$T/and-209-edge-land.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Profile"
- tapOn: "Gesture Lab"
- tapOn: "Gesture Taps"
- tapOn: {point: "100%,100%"}
- assertVisible: "Gesture Taps"
- takeScreenshot: "edge-100"
- tapOn: {point: "0%,0%"}
- assertVisible: "Gesture Taps"
- takeScreenshot: "edge-0"
YAML

for spec in AND-202:and-202-text-map AND-210:and-210-double-first AND-209:and-209-edge-land; do
  id=${spec%%:*}; name=${spec#*:}; d="$E/$id-targeted"
  mkdir -p "$d/input"
  cp "$T/$name.yaml" "$d/input/"
  rec "$id-targeted" "$GRANTIVA run --device emulator-5554 --no-build --flow $T/$name.yaml --report-dir $d/report; echo exit=\$?"
done

d="$E/AND-075-rerun-failure"; mkdir -p "$d/input"; cp .maestro/99-crash.yaml "$d/input/"
rec AND-075-rerun-failure "$GRANTIVA run --device emulator-5554 --no-build --logs --flow .maestro/99-crash.yaml --report-dir $d/report; rc=\$?; echo run-exit=\$rc; ps -axo pid,ppid,etime,command | grep '[a]db.*logcat' || true"

cp grantiva-android.yml "$S/grantiva-android.before-targeted-review.yml"
d="$E/AND-128-maestro-format"; mkdir -p "$d/input"
cp .maestro/coverage/cfg/maestro-format.grantiva-android.yml "$d/input/"
cp .maestro/coverage/cfg/maestro-format.grantiva-android.yml grantiva-android.yml
rec AND-128-maestro-format "rm -rf .grantiva/captures/android; $GRANTIVA diff capture --device emulator-5554 --no-build --verbose --json; echo exit=\$?; find .grantiva/captures/android -maxdepth 1 -type f -print | sort"
mkdir -p "$d/captures"; cp -R .grantiva/captures/android/. "$d/captures/"
cp "$S/grantiva-android.before-targeted-review.yml" grantiva-android.yml

rec B2-K107-a-exact "echo runner-home=$GRANTIVA_RUNNER_HOME; find $GRANTIVA_RUNNER_HOME/locks -maxdepth 1 -type f -print -exec stat -f 'inode=%i bytes=%z mtime=%Sm' {} \; 2>&1; test ! -e $GRANTIVA_RUNNER_HOME/locks/emulator-5554.lock; echo owned-device-lock-absent-exit=\$?"
