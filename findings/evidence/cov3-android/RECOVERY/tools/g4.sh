#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; D="--device emulator-5554 --no-build"; NEG=.maestro/coverage/02-exact-negative.yaml; B=.maestro/01-browse.yaml
# snapshot modes
rec AND-047 "rm -rf $S/sn-fail; $GRANTIVA run $D --flow $NEG --snapshot failure --report-dir $S/sn-fail; echo exit=\$?; find $S/sn-fail/captures $S/sn-fail/assets -type f | sort; find $S/sn-fail/allure-results -name '*.png' | wc -l"
rec AND-047 "rm -rf $S/sn-trail; $GRANTIVA run $D --flow $NEG --snapshot trailing --report-dir $S/sn-trail; echo exit=\$?; find $S/sn-trail/captures $S/sn-trail/assets -type f | sort; find $S/sn-trail/allure-results -name '*.png' | wc -l"
rec AND-047 "rm -rf $S/sn-full; $GRANTIVA run $D --flow $B --snapshot full --report-dir $S/sn-full; echo exit=\$?; find $S/sn-full/captures $S/sn-full/assets -type f | sort; find $S/sn-full/allure-results -name '*.png' | wc -l"
# report dir and captures dir untouched
rec AND-048 "find .grantiva -type f | sort > $S/g-before.txt; rm -rf $S/rd; $GRANTIVA run $D --flow $B --report-dir $S/rd; echo exit=\$?; ls $S/rd; find .grantiva -type f | sort > $S/g-after.txt; diff $S/g-before.txt $S/g-after.txt && echo grantiva-dir-unchanged"
# json pass/fail with and without report dir
rec AND-050 "$GRANTIVA run $D --flow $B --json --report-dir $S/js-pass; echo exit=\$?"
rec AND-050 "$GRANTIVA run $D --flow $NEG --json --report-dir $S/js-fail; echo exit=\$?"
rec AND-050 "$GRANTIVA run $D --flow $B --json; echo exit=\$?"
rec AND-050 "$GRANTIVA run $D --flow $NEG --json; echo exit=\$?"
rec AND-050 "$GRANTIVA run --device emulator-9999 --no-build --flow $B --json; echo exit=\$?"
# ready files
rec X-004 "rm -f $S/r-pass.json; $GRANTIVA run $D --flow $B --ready-file $S/r-pass.json; echo exit=\$?; cat $S/r-pass.json"
rec X-004 "rm -f $S/r-fail.json; $GRANTIVA run $D --flow $NEG --ready-file $S/r-fail.json --report-dir $S/r-fail-rd; echo exit=\$?; cat $S/r-fail.json"
rec X-004 "rm -f $S/r-int.json; bash $S/tools/intrun.sh $S/r-int 25 $D --flow .maestro/coverage/18-long-wait.yaml --ready-file $S/r-int.json; cat $S/r-int.err | tail -5; cat $S/r-int.json"
# no report dir: quiet / json / verbose / plain
rec D2-19 "$GRANTIVA run $D --flow $B; echo exit=\$?"
rec D2-19 "$GRANTIVA run $D --flow $B --quiet; echo exit=\$?"
rec D2-19 "$GRANTIVA run $D --flow $NEG --quiet; echo exit=\$?"
rec D2-19 "$GRANTIVA run $D --flow $B --json --verbose; echo exit=\$?"
rec D2-19 "$GRANTIVA run $D --flow $B --verbose; echo exit=\$?"
rec D2-19 "$GRANTIVA run $D --flow $B --quiet --verbose; echo exit=\$?"
# run-captures
rec N2-09 "rm -rf .grantiva/run-captures; $GRANTIVA run $D --flow $B; $GRANTIVA run $D --flow $NEG; find .grantiva -type f | sort; $GRANTIVA diff approve --json; echo exit=\$?; $GRANTIVA diff compare --json; echo exit=\$?"
rec N2-09 "rm -rf .grantiva/run-captures; $GRANTIVA run $D --flow $B --report-dir $S/n209a; $GRANTIVA run $D --flow $NEG --report-dir $S/n209b; ls -R .grantiva/run-captures 2>&1"
echo G4-DONE
