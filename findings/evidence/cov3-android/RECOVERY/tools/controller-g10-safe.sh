#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
B=.maestro/01-browse.yaml
rec AND-033 "$GRANTIVA run --emulator cov3-android --flow $B --ready-file /nonexistent-cov/sub/x.ready; echo exit=\$?"
rec AND-034 "echo '{\"status\":\"stale\"}' > $S/x.ready; $GRANTIVA run --device emulator-5554 --no-build --flow $B --ready-file $S/x.ready & p=\$!; sleep 3; ls $S/x.ready; wait \$p; echo exit=\$?; cat $S/x.ready"
rec AND-112 "$GRANTIVA build build --device emulator-5999; echo exit=\$?"
rec B2-K12 "$GRANTIVA run --platform android --no-build --device emulator-9999 --flow $B; echo missing-exit=\$?"
rec B2-K12 "$GRANTIVA run --no-build --device emulator-5554 --flow $B; echo serial-exit=\$?"
rec B2-K12 "$GRANTIVA run --no-build --emulator cov3-android --flow $B; echo avd-exit=\$?"
