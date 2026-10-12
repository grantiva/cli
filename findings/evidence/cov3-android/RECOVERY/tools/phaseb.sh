#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; CF=$S/cfgs; STOCK=$S/grantiva-android.yml.stock; APK=$S/app-free-debug.apk; B=.maestro/01-browse.yaml
TD="\$GRANTIVA emulator teardown --serial emulator-5554 >/dev/null 2>&1; sleep 3; adb devices"
EP="ps -o args= -p \$(python3 -I -c \"import json,os;print([r['pid'] for r in json.load(open(os.path.expanduser('~/.grantiva/android/started.json'))) if r['serial']=='emulator-5554'][0])\") | grep -o 'qemu-system-aarch64[-a-z]*\\|-no-window'"
# K104 / D2-30 while cov3-android runs
rec D2-30 "rm -rf /tmp/cov3-android-k104; cp -c -R $P /tmp/cov3-android-k104; rm -rf /tmp/cov3-android-k104/.grantiva; cd /tmp/cov3-android-k104 && bash $S/tools/ka2.sh $E/D2-30/ka emulator-5554 .maestro/01-browse.yaml; cat /tmp/grantiva-sessions/*.owner.json | python3 -I -c \"import sys,json; [print(json.dumps(json.loads(l))) for l in sys.stdin.read().replace('}{','}\\n{').splitlines() if 'cov3-android-k104' in l]\""
mcpc D2-30 $S/req/sess-probe.json /private/tmp/cov3-android-k104 --project-dir /private/tmp/cov3-android-k104 > /dev/null
mcpc D2-30 $S/req/sess-probe.json /tmp/cov3-android-k104 --project-dir /tmp/cov3-android-k104 > /dev/null
rec D2-30 "gp=\$(cat $E/D2-30/ka.pid); rp=\$(ls /tmp/grantiva-sessions | grep owner | while read f; do python3 -I -c \"import json;d=json.load(open('/tmp/grantiva-sessions/\$f'));print(d['runnerPid']) if d.get('grantivaPid')==\$gp else None\"; done); echo grantiva=\$gp runner=\$rp; kill -9 \$gp; t0=\$(date +%s); for i in \$(seq 1 30); do kill -0 \$rp 2>/dev/null || break; sleep 1; done; echo runner-exited-after=\$(( \$(date +%s)-t0 ))s; cd /tmp/cov3-android-k104 && \$GRANTIVA hierarchy --timeout 5 >/dev/null; echo hierarchy-exit=\$?; ls /tmp/grantiva-sessions"
rec D2-30 "cd /tmp/cov3-android-k104 && \$GRANTIVA runner start --detach >/dev/null 2>&1; cat /tmp/grantiva-sessions/*.owner.json 2>/dev/null | tr '}' '\n' | grep k104; echo; sleep 2; \$GRANTIVA hierarchy --format json | head -c 60; echo; \$GRANTIVA runner stop; rm -rf /tmp/cov3-android-k104"
# shut down: build boots nothing
rec AND-111 "$TD; \$GRANTIVA build build; echo exit=\$?; adb devices; ps -ax -o args= | grep -c '[q]emu-system.*cov3-android '"
rec B2-K54 "adb devices"
mcpc B2-K54 $S/req/build.json $P --project-dir $P > /dev/null
rec B2-K54 "adb devices; ps -ax -o args= | grep '[q]emu-system.*-avd cov3-android ' | cut -c1-120"
rec AND-114 "cp $CF/noemu.yml grantiva-android.yml; \$GRANTIVA run --no-build --flow $B; echo exit=\$?; cp $STOCK grantiva-android.yml; adb devices"
rec AND-113 "\$GRANTIVA build install; echo exit=\$?; adb devices; $EP"
rec AND-143 "$TD; \$GRANTIVA build install --emulator cov3-android --headless --module app; echo exit=\$?; $EP; adb -s emulator-5554 shell pidof com.kylebrowning.landmarks"
rec AND-029 "$TD; \$GRANTIVA run --emulator cov3-android --no-build --flow $B; echo exit=\$?; $EP"
rec AND-032 "$TD; \$GRANTIVA run --headless --emulator cov3-android --no-build --flow $B; echo exit=\$?; $EP"
rec AND-140 "$TD; \$GRANTIVA diff capture --emulator cov3-android --module app --variant freeDebug --headless; echo exit=\$?; $EP"
rec AND-142 "$TD; \$GRANTIVA diff compare --capture --emulator cov3-android --module app --variant freeDebug --application-id com.kylebrowning.landmarks --headless; echo exit=\$?; $EP"
rec AND-142 "\$GRANTIVA diff compare --capture --device emulator-5554 --no-build; echo exit=\$?"
rec AND-142 "\$GRANTIVA diff compare --capture --app-file $APK; echo exit=\$?"
rec AND-142 "\$GRANTIVA diff compare --capture --allow-device-settings --no-build; echo exit=\$?"
rec AND-141 "\$GRANTIVA diff capture --app-file $APK --verbose 2>&1 | grep -E 'apkanalyzer|gradlew|Using pre-built|Installing|Captured' | cut -c1-200; echo exit=\${PIPESTATUS[0]}"
rec D2-09 "$TD; adb devices; \$GRANTIVA diff capture --no-build --app-file $APK; echo exit=\$?; adb devices"
rec AND-115 "$TD; cp $CF/noemu.yml grantiva-android.yml; (\$GRANTIVA emulator ensure --name cov3-android > $S/ens115.out 2> $S/ens115.err &); sleep 4; adb devices; \$GRANTIVA run --no-build --flow $B; echo exit=\$?; cp $STOCK grantiva-android.yml; cat $S/ens115.out $S/ens115.err"
echo PHASEB-DONE
