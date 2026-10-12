#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd $P; ST="bash $S/tools/settings.sh emulator-5554"; KA="bash $S/tools/ka.sh"
# N-08 before + stock run without the dir on PATH (also AND-120 rerun)
rec N-08 "D=\$(cat $S/n08dir.txt); find \"\$D\" -type f -exec stat -f '%m %N' {} + 2>/dev/null | sed \"s|\$D|\\\$D|g\" | sort > $S/n08-before.txt; wc -l < $S/n08-before.txt; echo \"\$PATH\" | tr ':' '\n' | grep -c \"\$D\""
rec AND-120 "D=\$(cat $S/n08dir.txt); export PATH=\$(echo \"\$PATH\" | tr ':' '\n' | grep -v \"\$D\" | paste -sd: -); rm -rf $S/sf-full2; $GRANTIVA run --device emulator-5554 --no-build --report-dir $S/sf-full2 --snapshot full; echo exit=\$?; ls $S/sf-full2 $S/sf-full2/screens; find $S/sf-full2 -path '*trace*' -name '*.png' | wc -l"
rec N-08 "D=\$(cat $S/n08dir.txt); find \"\$D\" -type f -exec stat -f '%m %N' {} + 2>/dev/null | sed \"s|\$D|\\\$D|g\" | sort > $S/n08-after.txt; diff $S/n08-before.txt $S/n08-after.txt && echo unchanged"
# keep-alive cleanup + settings (AND-059/065/066/067, AND-061 race, AND-063 refusal)
rec AND-059 "$ST; rm -f $E/AND-059/ka.ready; nohup $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file $E/AND-059/ka.ready > $E/AND-059/ka.out 2> $E/AND-059/ka.err & echo \$! > $E/AND-059/ka.pid; for i in \$(seq 1 120); do [ -f $E/AND-059/ka.ready ] && break; sleep 1; done; t=\$(date +%s); $GRANTIVA hierarchy > /dev/null; echo hierarchy-right-after-ready=\$? ; cat $E/AND-059/ka.ready; echo; $ST; ls /tmp/grantiva-sessions; ls .grantiva/android-settings-*.json; cat .grantiva/android-settings-emulator-5554.json"
rec AND-063 "$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml; echo exit=\$?; ls .grantiva/run-captures/android | grep -c failure"
rec AND-059 "ls .grantiva/run-captures/android | grep failure | sort > $S/fail-before.txt; kill -INT \$(cat $E/AND-059/ka.pid); sleep 6; kill -0 \$(cat $E/AND-059/ka.pid) 2>/dev/null && echo still-running || echo exited; tail -4 $E/AND-059/ka.err; cat $E/AND-059/ka.ready; echo; $ST; ls /tmp/grantiva-sessions; ls .grantiva/android-settings-*.json 2>&1; ls .grantiva/run-captures/android | grep failure | sort | diff $S/fail-before.txt - && echo no-new-failure-png"
# interrupt during flows with ready (AND-060)
rec AND-060 "rm -f $E/AND-060/r.json; nohup $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/coverage/18-long-wait.yaml --keep-alive --ready-file $E/AND-060/r.json > $E/AND-060/run.out 2> $E/AND-060/run.err & p=\$!; sleep 25; kill -INT \$p; wait \$p; echo exit=\$?; cat $E/AND-060/r.json; echo; $ST; ls /tmp/grantiva-sessions"
# kill -9 mid-run then next run restores (AND-068 / AND-066 during)
rec AND-068 "nohup $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/11-slow.yaml > $E/AND-068/run1.out 2> $E/AND-068/run1.err & p=\$!; sleep 20; $ST; cat .grantiva/android-settings-emulator-5554.json; echo; kill -9 \$p; sleep 2; $ST; ls .grantiva/android-settings-*.json; $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml 2>&1 | grep -E 'Warning|restor' ; $ST; ls .grantiva/android-settings-*.json 2>&1; ps -ax -o pid=,args= | grep '[g]rantiva-runner.*emulator-5554' | cut -c1-120"
# allow-device-settings
rec AND-145 "nohup $GRANTIVA run --allow-device-settings --emulator cov3-android --no-build --flow .maestro/11-slow.yaml > $E/AND-145/run.out 2> $E/AND-145/run.err & p=\$!; sleep 20; $ST; wait \$p; echo exit=\$?; $ST; tail -3 $E/AND-145/run.err"
# D2-14 keep-alive + runner stop (pass and fail)
rec D2-14 "rm -f $E/D2-14/r1.json; $KA $E/D2-14/ka1 .maestro/01-browse.yaml >/dev/null; cat $E/D2-14/ka1.ready > $E/D2-14/r1-before.json; $GRANTIVA runner stop --json; echo exit=\$?; sleep 3; cat $E/D2-14/ka1.ready; diff $E/D2-14/r1-before.json $E/D2-14/ka1.ready && echo ready-unchanged; kill -0 \$(cat $E/D2-14/ka1.pid) 2>/dev/null && echo run-alive || echo run-exited"
rec D2-14 "$KA $E/D2-14/ka2 .maestro/coverage/02-exact-negative.yaml >/dev/null; cat $E/D2-14/ka2.ready > $E/D2-14/r2-before.json; $GRANTIVA runner stop --json; echo exit=\$?; sleep 3; cat $E/D2-14/ka2.ready; diff $E/D2-14/r2-before.json $E/D2-14/ka2.ready && echo ready-unchanged; kill -0 \$(cat $E/D2-14/ka2.pid) 2>/dev/null && echo run-alive || echo run-exited"
# K107-a lock files
rec B2-K107-a "ls -la $GRANTIVA_RUNNER_HOME/locks 2>&1 | head -30"
echo G9-DONE
