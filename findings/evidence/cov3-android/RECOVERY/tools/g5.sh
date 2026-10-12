#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; CF=$S/cfgs; STOCK=$S/grantiva-android.yml.stock; D="--device emulator-5554 --no-build"
cp $CF/a.yaml $CF/b.yaml $CF/sub.yaml $P/
W(){ echo "cp $CF/$1 grantiva-android.yml; $2; rc=\$?; cp $STOCK grantiva-android.yml; exit \$rc"; }
# timeouts
rec AND-049 "rm -rf $S/to-flow; $GRANTIVA run $D --flow .maestro/coverage/18-long-wait.yaml --timeout 30 --ready-file $S/to-flow.ready --report-dir $S/to-flow; echo exit=\$?; cat $S/to-flow.ready; python3 -I -c \"import json;r=json.load(open('$S/to-flow/report.json'));print('report',r['status'],r['summary']);f=json.load(open('$S/to-flow/flows/flow-000.json'));print('flow',f.get('status'),json.dumps(f.get('error'))[:300])\"; grep -c 'failure' $S/to-flow/junit-report.xml"
rec AND-119 "$(W ../android/.maestro/coverage/cfg/screens-slow.grantiva-android.yml "rm -rf $S/to-scr; $GRANTIVA run $D --timeout 30 --ready-file $S/to-scr.ready --report-dir $S/to-scr; echo exit=\$?; cat $S/to-scr.ready; python3 -I -c \"import json;r=json.load(open('$S/to-scr/screens/report.json'));print('report',r['status'],r['summary'])\"")"
rec AND-119 "$(W ../android/.maestro/coverage/cfg/screens-fail.grantiva-android.yml "rm -rf $S/cof; $GRANTIVA run $D --continue-on-failure --ready-file $S/cof.ready --report-dir $S/cof; echo exit=\$?; cat $S/cof.ready")"
rec AND-046 "$(W crashfirst.yml "$GRANTIVA run $D --continue-on-failure --report-dir $S/crashfirst; echo exit=\$?")"
# narration counts
rec B2-K13 "$(W flowsonly.yml "$GRANTIVA run $D 2>&1 | grep -E 'Running|Capturing|flow\\(s\\)|screen\\(s\\)'; echo exit=\${PIPESTATUS[0]}")"
rec B2-K13 "$(W screensonly.yml "$GRANTIVA run $D 2>&1 | grep -E 'Running|Capturing|flow\\(s\\)|screen\\(s\\)'; echo exit=\${PIPESTATUS[0]}")"
# failing stock config summary
rec S2-03 "$(W stockneg.yml "$GRANTIVA run $D --report-dir $S/stockneg --ready-file $S/stockneg.ready; echo exit=\$?; cat $S/stockneg.ready")"
# screens + flows full snapshot report
rec AND-120 "rm -rf $S/sf-full; $GRANTIVA run $D --report-dir $S/sf-full --snapshot full; echo exit=\$?; ls $S/sf-full $S/sf-full/screens; find $S/sf-full -path '*trace*' -name '*.png' | wc -l"
echo G5-DONE
