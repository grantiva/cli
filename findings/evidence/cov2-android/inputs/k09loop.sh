#!/bin/bash
# k09loop.sh <n>: pointer_location on, n runs of c-direction-left-from.yaml (pm clear before each), After capture thumbnails
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/env.sh
d=$E/CF-k09; mkdir -p $d/after; adb -s emulator-5554 shell settings put system pointer_location 1
for i in $(seq 1 $1); do
  adb -s emulator-5554 shell pm clear com.kylebrowning.landmarks >/dev/null
  $S/tools/cflow.sh k09-$i .maestro/coverage/c-direction-left-from.yaml | head -1
  grep -E 'swipe|assertNotVisible' $E/CF-k09-$i/run.err | head -2
  f=$(ls $S/cf/k09-$i/assets/flow-000/*After*.png 2>/dev/null | head -1); [ -n "$f" ] && cp "$f" $d/after/run$i-after-full.png && sips -c 900 1080 --cropOffset 250 0 "$f" --out $d/after/run$i-crop.png >/dev/null && sips -Z 400 $d/after/run$i-crop.png >/dev/null
  grep -h 'swipe' $S/cf/k09-$i/maestro-runner.log | grep -i 'from\|start\|coord' | head -3
done
adb -s emulator-5554 shell settings put system pointer_location 0
