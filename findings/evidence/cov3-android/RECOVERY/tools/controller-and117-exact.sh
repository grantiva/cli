#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
d="$E/AND-117-exact"; mkdir -p "$d/input"
cp .maestro/coverage/11-launch-environment.yaml "$d/input/"
cp .maestro/coverage/12-env-precedence-cli.yaml "$d/input/"
rec AND-117-exact "$GRANTIVA run --device emulator-5554 --no-build --env LANDMARKS_NOTE=from-cli --flow .maestro/coverage/12-env-precedence-cli.yaml --report-dir $d/report; echo exit=\$?"
