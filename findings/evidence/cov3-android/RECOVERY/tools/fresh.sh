#!/bin/bash
# fresh.sh: 3 x (delete cov3-android-2, ensure (create+boot), install apk, first diff capture); then seed-many runs on the last fresh AVD
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P
for i in 1 2 3; do
  rec B2-K06 "\$GRANTIVA emulator delete --name cov3-android-2 >/dev/null 2>&1; s=\$(\$GRANTIVA emulator ensure --name cov3-android-2 2>&1 >/dev/null | tail -1; ); serial=\$(adb devices | awk '/emulator-5556/{print \$1}'); echo \"\$s serial=\$serial\"; \$GRANTIVA build install --no-build --app-file $S/app-free-debug.apk --device emulator-5556 --no-launch; t0=\$(date +%s); \$GRANTIVA diff capture --no-build --device emulator-5556 > $E/B2-K06/capture$i.out 2> $E/B2-K06/capture$i.err; echo capture$i-exit=\$? secs=\$(( \$(date +%s)-t0 )); grep -c '^Warning' $E/B2-K06/capture$i.err; grep -E '^Warning|^Error|refused|connection|UIAutomator2' $E/B2-K06/capture$i.err | cut -c1-250 | head -5; grep -E 'Captured|•' $E/B2-K06/capture$i.out"
done
for i in 1 2 3 4 5; do bash $S/tools/seedmany2.sh emulator-5556 fresh-d$i > $E/B2-K07/fresh-d$i.txt 2>&1; done
for i in 1 2; do bash $S/tools/seedmany2.sh emulator-5556 fresh-f$i --snapshot full > $E/B2-K07/fresh-f$i.txt 2>&1; done
for i in 1 2 3; do bash $S/tools/seedmany2.sh emulator-5554 warm-d$i > $E/B2-K07/warm-d$i.txt 2>&1; done
echo FRESH-DONE
