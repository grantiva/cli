#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
runflow() {
  id=$1; flow=$2; d="$E/$id-targeted"
  mkdir -p "$d/input"; cp "$flow" "$d/input/"
  rec "$id-targeted" "$GRANTIVA run --device emulator-5554 --no-build --flow $flow --report-dir $d/report; echo exit=\$?"
}
runflow AND-206 .maestro/coverage/02-exact-negative.yaml
T=.maestro/coverage/cov3-targeted-and207.yaml
cat > "$T" <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp: {clearState: true}
- tapOn: "Lakes"
- tapOn: {text: "(Lake .*|.* Lake)", index: 1}
- assertVisible: "Mono Lake"
- assertVisible: "Lee Vining, CA"
- assertNotVisible: "Lake Tahoe"
YAML
runflow AND-207 "$T"
runflow AND-219 .maestro/coverage/07-swipe-from-missing.yaml
runflow AND-213 .maestro/coverage/15-input-unicode.yaml
runflow AND-225 .maestro/coverage/14-runflow.yaml
runflow AND-226 .maestro/coverage/14b-runflow-inline.yaml
