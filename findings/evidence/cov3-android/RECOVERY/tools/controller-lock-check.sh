#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
rec B2-K107-a "find $GRANTIVA_RUNNER_HOME/locks -maxdepth 1 -type f -print | sort; find $GRANTIVA_RUNNER_HOME/locks -maxdepth 1 -type f -name '*emulator*' -o -name '*5554*' -print; test -e $GRANTIVA_RUNNER_HOME/locks/emulator-5554.lock; echo exact-lock-exists=\$?"
