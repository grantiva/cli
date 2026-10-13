#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; D="--device emulator-5554 --no-build"; LL="adb -s emulator-5554 logcat -d -s Landmarks:I | grep 'launch action' | tail -1"
LC="ps -ax -o pid=,args= | grep '[a]db.*emulator-5554.*logcat' || echo no-logcat-process"
rec AND-035 "$GRANTIVA run $D --flow .maestro/coverage/qa-note.yaml --env 'LANDMARKS_NOTE=a=b c'; echo exit=\$?; $LL"
rec AND-037 "$GRANTIVA run $D --flow .maestro/coverage/22-show-note.yaml --env LANDMARKS_NOTE=hello; echo exit=\$?; $LL; adb -s emulator-5554 shell uiautomator dump /sdcard/u.xml >/dev/null; adb -s emulator-5554 shell cat /sdcard/u.xml | grep -o 'text=\"hello\"'"
rec AND-038 "$GRANTIVA run $D --flow .maestro/coverage/08-scroll.yaml --env LANDMARKS_SEED=many --env LANDMARKS_NOTE=x; echo exit=\$?; $LL"
rec AND-039 "$GRANTIVA run $D --flow .maestro/coverage/env-empty.yaml --env LANDMARKS_SEED=empty; echo exit=\$?; $LL; $GRANTIVA run $D --flow .maestro/09-seed-empty.yaml; echo exit=\$?; $LL"
rec AND-040 "rm -f $S/crashenv.ready; $GRANTIVA run $D --flow .maestro/01-browse.yaml --env LANDMARKS_CRASH_ON_LAUNCH=1 --ready-file $S/crashenv.ready; echo exit=\$?; cat $S/crashenv.ready; ls .grantiva/run-captures/android | grep failure | tail -1"
rec B-A01.1 "$GRANTIVA run $D --flow .maestro/10-seed-many.yaml; echo exit=\$?; $LL"
# logs
rec AND-071 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs > $E/AND-071/run.out 2> $E/AND-071/run.err; echo exit=\$?; grep -c '^\[log\]' $E/AND-071/run.err; grep '^\[log\]' $E/AND-071/run.err | head -5; $LC"
rec AND-072 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs-tag Landmarks 2> $E/AND-072/run.err; echo exit=\$?; grep -c '^\[log\]' $E/AND-072/run.err; grep '^\[log\]' $E/AND-072/run.err | awk '{print \$6}' | sort | uniq -c | head; grep '^\[log\]' $E/AND-072/run.err | head -3"
rec AND-073 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs --verbose 2> $E/AND-073/none.err; echo exit=\$?; grep -o 'logcat.*' $E/AND-073/none.err | grep -m2 '\\\$\|\*:' ; grep '^\[log\]' $E/AND-073/none.err | awk '{print \$6}' | sort | uniq -c"
rec AND-073 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs --logs-level default --verbose 2> $E/AND-073/default.err; echo exit=\$?; grep -o 'logcat.*' $E/AND-073/default.err | grep -m2 '\*:'; grep '^\[log\]' $E/AND-073/default.err | awk '{print \$6}' | sort | uniq -c"
rec AND-073 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs --logs-level info --verbose 2> $E/AND-073/info.err; echo exit=\$?; grep -o 'logcat.*' $E/AND-073/info.err | grep -m2 '\*:'; grep '^\[log\]' $E/AND-073/info.err | awk '{print \$6}' | sort | uniq -c"
rec AND-073 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs --logs-level debug --verbose 2> $E/AND-073/debug.err; echo exit=\$?; grep -o 'logcat.*' $E/AND-073/debug.err | grep -m2 '\*:'; grep '^\[log\]' $E/AND-073/debug.err | awk '{print \$6}' | sort | uniq -c"
rec AND-073 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs --logs-level warning; echo exit=\$?"
rec AND-123 "adb -s emulator-5554 shell log -p i -t Landmarks COV2-MARKER-BEFORE-RUN; sleep 2; $GRANTIVA run $D --flow .maestro/08-caching.yaml --logs 2> $E/AND-123/run.err; echo exit=\$?; grep -c COV2-MARKER-BEFORE-RUN $E/AND-123/run.err; adb -s emulator-5554 logcat -d | grep -c COV2-MARKER-BEFORE-RUN"
rec AND-075 "$GRANTIVA run $D --flow .maestro/08-caching.yaml --logs >/dev/null 2>&1; echo success-exit=\$?; sleep 1; $LC"
rec AND-075 "$GRANTIVA run $D --flow .maestro/99-crash.yaml --logs >/dev/null 2>&1; echo failure-exit=\$?; sleep 1; $LC"
rec AND-075 "bash $S/tools/intrun.sh $S/logint 25 $D --flow .maestro/11-slow.yaml --logs; sleep 2; $LC; tail -3 $S/logint.err"
echo G6-DONE
