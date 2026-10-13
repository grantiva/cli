#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
for d in AND-035-exact AND-039-cli-exact AND-039-header-exact; do mkdir -p "$E/$d/input"; done
cp .maestro/coverage/22-show-note.yaml "$E/AND-035-exact/input/"
cp .maestro/09-seed-empty.yaml "$E/AND-039-cli-exact/input/"
cp .maestro/09-seed-empty.yaml "$E/AND-039-header-exact/input/"
rec AND-035-exact "$GRANTIVA run --device emulator-5554 --no-build --env 'LANDMARKS_NOTE=a=b c' --flow .maestro/coverage/22-show-note.yaml --report-dir $E/AND-035-exact/report; echo exit=\$?; adb -s emulator-5554 logcat -d -s Landmarks:I | tail -30"
rec AND-039-cli-exact "$GRANTIVA run --device emulator-5554 --no-build --env LANDMARKS_SEED=empty --flow .maestro/09-seed-empty.yaml --report-dir $E/AND-039-cli-exact/report; echo exit=\$?"
rec AND-039-header-exact "$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/09-seed-empty.yaml --report-dir $E/AND-039-header-exact/report; echo exit=\$?"
rec AND-074-exact "$GRANTIVA run --device emulator-5554 --no-build --logs-predicate x --flow .maestro/01-browse.yaml; echo exit=\$?"
rec AND-089-exact "$GRANTIVA ci run; echo exit=\$?"
