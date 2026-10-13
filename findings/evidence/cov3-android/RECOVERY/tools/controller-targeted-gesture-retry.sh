#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
T=.maestro/coverage/cov3-targeted-gesture-retry
mkdir -p "$T"
cat > "$T/and-210-double-first.yaml" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
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
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- tapOn: {point: "100%,100%"}
- assertVisible: "Gesture Lab"
- takeScreenshot: "edge-100"
- tapOn: {point: "0%,0%"}
- assertVisible: "Gesture Lab"
- takeScreenshot: "edge-0"
YAML
for spec in AND-210:and-210-double-first AND-209:and-209-edge-land; do
  id=${spec%%:*}; name=${spec#*:}; d="$E/$id-targeted-retry"
  mkdir -p "$d/input"; cp "$T/$name.yaml" "$d/input/"
  rec "$id-targeted-retry" "$GRANTIVA run --device emulator-5554 --no-build --flow $T/$name.yaml --report-dir $d/report; echo exit=\$?"
done
