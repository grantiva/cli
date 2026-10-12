#!/bin/zsh
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke5/env.sh
F=$S/flowrun.sh
( cd $S/demo/android; rec $E/A1/run.txt $GRANTIVA run --device $SER --no-build --report-dir $S/rA1; f=$(find $S/rA1 -name maestro-runner.log | head -1); [[ -n $f ]] && tail -200 $f > $E/A1/run-maestro-runner-tail.log )
for i in 1 2 3; do
  adb -s $SER logcat -b crash -c
  $F android .maestro/99-crash.yaml $E/A3-crash crash-$i
  { echo "## run $i host $(date +%H:%M:%S) device $(adb -s $SER shell date +%H:%M:%S)"; adb -s $SER logcat -b crash -d -v time | grep -E "FATAL|LANDMARKS_CRASH" ; grep -E "Step [0-9]+ (failed|completed)|crashed=true|app_crash|launch_app" $E/A3-crash/crash-$i-maestro-runner.log | cut -c1-240; echo "## report dir files (mtime)"; find $S/reports/crash-$i -type f -exec stat -f '%Sm %N' -t '%H:%M:%S' {} \; | sort; } >> $E/A3-crash/device-crash-times.txt 2>&1
done
for i in 1 2 3; do $F android .maestro/03-edit.yaml $E/A1-03edit run-$i; done
for i in 1 2 3 4 5; do $F android .maestro/coverage/03-gesture-lab-taps.yaml $E/A-doubletap dt-$i; done
for i in 1 2 3 4 5; do $F android .maestro/02-favorite.yaml $E/L62-02favorite fav-$i; done
echo BATCH-DONE
