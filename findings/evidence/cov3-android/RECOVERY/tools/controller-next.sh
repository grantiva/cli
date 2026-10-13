#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
rec AND-075-rerun "$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/08-caching.yaml --logs; echo exit=\$?; sleep 1; ps -ax -o pid=,args= | grep '[a]db.*emulator-5554.*logcat' || echo no-logcat-process"
rec AND-075-rerun "nohup $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/coverage/18-long-wait.yaml --logs > $E/AND-075-rerun/interrupt.out 2> $E/AND-075-rerun/interrupt.err & p=\$!; sleep 5; kill -INT \$p; wait \$p; echo interrupt-exit=\$?; sleep 1; ps -ax -o pid=,args= | grep '[a]db.*emulator-5554.*logcat' || echo no-logcat-process"
