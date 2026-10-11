#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/env.sh
cd $P; CF=$S/cfgs; STOCK=$S/grantiva-android.yml.stock; B=.maestro/01-browse.yaml
TD="\$GRANTIVA emulator teardown --serial emulator-5554 >/dev/null 2>&1; sleep 3; adb devices"
EP="ps -o args= -p \$(python3 -I -c \"import json,os;print([r['pid'] for r in json.load(open(os.path.expanduser('~/.grantiva/android/started.json'))) if r['serial']=='emulator-5554'][0])\") | grep -o 'qemu-system-aarch64[-a-z]*\\|-no-window'"
rec AND-113 "$TD; \$GRANTIVA build install; echo exit=\$?; adb devices; $EP; adb -s emulator-5554 shell pm list packages com.kylebrowning.landmarks"
rec AND-113 "adb -s emulator-5554 shell pm list packages com.kylebrowning.landmarks; $TD; \$GRANTIVA emulator ensure --name cov2-android; adb -s emulator-5554 shell pm list packages com.kylebrowning.landmarks; echo pm-exit=\$?"
rec AND-114 "$TD; cp $CF/noemu.yml grantiva-android.yml; \$GRANTIVA run --no-build --flow $B; echo exit=\$?; cp $STOCK grantiva-android.yml; adb devices; ps -ax -o args= | grep -c '[q]emu-system'"
rec N-02 "adb devices"
mcpc N-02 $S/req/buildonly.json $P --project-dir $P > /dev/null
rec N-02 "adb devices; ps -ax -o args= | grep -c '[q]emu-system'"
rec AND-029 "\$GRANTIVA run --emulator cov2-android --flow $B; echo exit=\$?; $EP"
rec AND-032 "$TD; \$GRANTIVA run --headless --emulator cov2-android --flow $B; echo exit=\$?; $EP"
rec AND-140 "$TD; \$GRANTIVA diff capture --emulator cov2-android --module app --variant freeDebug --headless --verbose 2>&1 | grep -E 'gradlew|assemble|Booting|Installing|install|Captured|Emulator:' | grep -v 'pm list' | cut -c1-220; $EP"
rec AND-115 "$TD; cp $CF/noemu.yml grantiva-android.yml; (\$GRANTIVA emulator ensure --name cov2-android > $S/ens115.out 2> $S/ens115.err &); sleep 4; adb devices; \$GRANTIVA run --flow $B; echo exit=\$?; cp $STOCK grantiva-android.yml; cat $S/ens115.out $S/ens115.err"
echo REDO-DONE
