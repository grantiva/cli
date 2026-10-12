#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P
for i in 4 5; do
  rec B2-K06 "\$GRANTIVA emulator teardown --serial emulator-5556 >/dev/null 2>&1; sleep 3; \$GRANTIVA emulator delete --name cov3-android-2; s=\$(\$GRANTIVA emulator ensure --name cov3-android-2 2>&1 >/dev/null | tail -1); echo \"\$s\"; \$GRANTIVA build install --no-build --app-file $S/app-free-debug.apk --device emulator-5556 --no-launch; t0=\$(date +%s); \$GRANTIVA diff capture --no-build --device emulator-5556 > $E/B2-K06/capture$i.out 2> $E/B2-K06/capture$i.err; echo capture$i-exit=\$? secs=\$(( \$(date +%s)-t0 )); grep -c '^Warning' $E/B2-K06/capture$i.err; grep -E '^Warning|^Error|refused|connection' $E/B2-K06/capture$i.err | cut -c1-250 | head -5; grep -E 'Captured|•' $E/B2-K06/capture$i.out"
done
echo FRESH2-DONE
