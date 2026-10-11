#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/env.sh
cd $P; CF=$S/cfgs; STOCK=$S/grantiva-android.yml.stock; B=.maestro/01-browse.yaml
W(){ echo "cp $1 grantiva-android.yml; $2; rc=\$?; cp $STOCK grantiva-android.yml; exit \$rc"; }
rec AND-026 "$GRANTIVA run --device emulator-5554 --variant paidDebug --flow $B --report-dir $S/paid; echo exit=\$?; python3 -I -c \"import json;r=json.load(open('$S/paid/report.json'));print('report app',r.get('app'))\""
rec AND-027 "$GRANTIVA run --device emulator-5554 --application-id com.kylebrowning.landmarks.debug --flow $B; echo exit=\$?; adb -s emulator-5554 shell pm list packages com.kylebrowning"
rec AND-028 "adb -s emulator-5554 uninstall com.kylebrowning.landmarks; $GRANTIVA run --device emulator-5554 --app-file $S/app-free-debug.apk --flow $B --verbose 2>&1 | grep -E 'apkanalyzer|Gradle|gradlew|Installing|Using pre-built|✓ 01-browse|✗|Error' | cut -c1-220; adb -s emulator-5554 shell pm list packages com.kylebrowning.landmarks"
rec AND-033 "$GRANTIVA run --emulator cov2-android --flow $B --ready-file /nonexistent-cov/sub/x.ready; echo exit=\$?"
rec AND-034 "echo '{\"status\":\"stale\"}' > $S/x.ready; $GRANTIVA run --device emulator-5554 --no-build --flow $B --ready-file $S/x.ready 2>/dev/null & p=\$!; sleep 3; ls $S/x.ready 2>&1; wait \$p; echo exit=\$?; cat $S/x.ready"
rec AND-036 "$(W $CF/noemu.yml "$GRANTIVA run --no-build --flow $B 2>&1 | grep -E 'Resolved|Using|Booting|✓ 01-browse|Error'; echo exit=\${PIPESTATUS[0]}")"
rec AND-112 "$GRANTIVA build build --device emulator-5999; echo exit=\$?"
rec B2-K12 "$GRANTIVA run --platform android --no-build --device emulator-9999 --flow $B; echo exit=\$?; $GRANTIVA run --no-build --device emulator-5554 --flow $B 2>&1 | grep -E 'Using|Booting'; $GRANTIVA run --no-build --emulator cov2-android --flow $B 2>&1 | grep -E 'Using|Booting'"
rec B2-K23-a "cd $S/flowonly && $GRANTIVA run --platform android --device emulator-5554 --no-build --flow 16-setpermissions.yaml; echo exit=\$?"
rec B2-K23-a "cd $S/flowonly && sed 's/^appId: .*/appId: \${APP_ID}/' 16-setpermissions.yaml > var.yaml && $GRANTIVA run --platform android --device emulator-5554 --no-build --flow var.yaml; echo exit=\$?; rm var.yaml"
# D2-08: app-file installs with --no-build
rec D2-08 "adb -s emulator-5554 uninstall com.kylebrowning.landmarks; $GRANTIVA run --device emulator-5554 --no-build --app-file $S/app-free-debug.apk --flow $B 2>&1 | grep -E 'Installing|Using pre-built|Skipping|✓ 01-browse|Error'; adb -s emulator-5554 shell pm list packages com.kylebrowning.landmarks"
rec D2-08 "adb -s emulator-5554 uninstall com.kylebrowning.landmarks; $GRANTIVA diff capture --device emulator-5554 --no-build --app-file $S/app-free-debug.apk 2>&1 | grep -E 'Installing|Using pre-built|Skipping|Captured|Error'; adb -s emulator-5554 shell pm list packages com.kylebrowning.landmarks"
rec D2-08 "adb -s emulator-5554 uninstall com.kylebrowning.landmarks; $GRANTIVA ci run --device emulator-5554 --no-build --app-file $S/app-free-debug.apk; echo exit=\$?; adb -s emulator-5554 shell pm list packages com.kylebrowning.landmarks; adb -s emulator-5554 install -r $S/app-free-debug.apk"
# MCP build/run/context/vrt with config, without config, both configs
mcpc AND-101 $S/req/build.json $P --project-dir $P > /dev/null
mcpc MCP-032 $S/req/nocfg.json $S/nocfg --project-dir $S/nocfg > /dev/null
mcpc AND-105 $S/req/sess-probe.json $S/both --project-dir $S/both --platform android > /dev/null
mcpc AND-105 $S/req/sess-probe.json $S/both --project-dir $S/both > /dev/null
rec AND-104 "MCP_WAIT=60 MCP_TIMEOUT=120 bash $S/tools/send.sh $P - $S/req/burst.jsonl > $E/AND-104/stdout.jsonl 2> $E/AND-104/stderr.txt; python3 -I -c \"
import json
ids=[];err=0;iserr=0
for l in open('$E/AND-104/stdout.jsonl'):
  if not l.startswith('{'): continue
  d=json.loads(l); ids.append(d.get('id')); err+= 'error' in d; iserr+= bool(d.get('result',{}).get('isError'))
print('responses',len(ids),'ids',sorted(i for i in ids if i is not None)[:3],'..',max(i for i in ids if i is not None),'rpc_errors',err,'isError',iserr)\""
echo G10-DONE
