#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/env.sh
cd $P
for i in 1 2 3 4 5 6 7 8 9 10; do $S/tools/cflow.sh k08-$i .maestro/coverage/09-waits.yaml | grep -E '^==|notVisible|✗' ; done > $E/inputs/k08-summary.txt
rec B2-K105 "\$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/coverage/14-runflow.yaml --verbose --report-dir $S/k105 2>&1 | grep -E 'runFlow|▸ Run' | grep -v debug | sort | uniq -c; grep -o '\"yaml\": \"runFlow[^\"]*\"' $S/k105/flows/flow-000.json; grep -o 'name=\"[^\"]*runflow[^\"]*\"' $S/k105/junit-report.xml | sort -u"
rec AND-144 "cd $S/both && \$GRANTIVA build install --platform android --no-launch; echo exit=\$?; \$GRANTIVA build install --no-launch; echo exit-without-platform=\$?"
rec B-C02.2 "\$GRANTIVA emulator ensure --name cov2-android-2 --no-boot >/dev/null 2>&1; python3 -I -c \"import socket,time,os;s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(('127.0.0.1',5556));s.listen(1);open('$S/listener.pid','w').write(str(os.getpid()));time.sleep(180)\" & sleep 2; lsof -nP -iTCP:5556 -sTCP:LISTEN | tail -1; \$GRANTIVA emulator ensure --name cov2-android-2; echo exit=\$?; cat ~/.grantiva/android/started.json; echo; adb devices; s=\$(adb devices | awk '/emulator-55(58|60|62)/{print \$1}' | head -1); echo serial=\$s; \$GRANTIVA emulator teardown --serial \$s; kill \$(cat $S/listener.pid); sleep 3; \$GRANTIVA emulator delete --name cov2-android-2; avdmanager list avd -c"
echo FINAL1-DONE
