#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; CF=$S/cfgs; STOCK=$S/grantiva-android.yml.stock
cp $CF/a.yaml $CF/b.yaml $P/
rec B2-K90-b "cp $CF/k90b.yml grantiva-android.yml; $GRANTIVA diff capture --device emulator-5554 --no-build; echo exit=\$?; cp $STOCK grantiva-android.yml"
rec B-A04.1 "for i in 1 2 3 4 5 6 7 8 9 10; do $GRANTIVA diff capture --device emulator-5554 --no-build >/dev/null 2>&1; echo \"run \$i exit=\$? home=\$(md5 -q .grantiva/captures/android/Home.png) deeplinks=\$(md5 -q '.grantiva/captures/android/Deep Links.png') homeKB=\$(( \$(stat -f %z .grantiva/captures/android/Home.png)/1024 ))\"; done"
rec MCP-069 "$GRANTIVA runner start --detach --device emulator-5554 >/dev/null 2>&1; cp .maestro/coverage/cfg/screens-steps.grantiva-android.yml grantiva-android.yml; ls -la .grantiva/captures/android | wc -l"
mcpc MCP-069 $S/req/vrtonly.json $P --project-dir $P > /dev/null
rec D2-41 "cp $CF/typenofocus.yml grantiva-android.yml"
mcpc D2-41 $S/req/vrtonly.json $P --project-dir $P > /dev/null
rec D2-41 "cp $STOCK grantiva-android.yml; $GRANTIVA runner stop"
echo G12-DONE
