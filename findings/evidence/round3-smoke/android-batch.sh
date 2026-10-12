#!/bin/zsh
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/smoke4/env.sh
F=$S/flowrun.sh
for i in 1 2 3; do
  adb -s $SER logcat -b crash -c
  $F android .maestro/99-crash.yaml $E/A3-crash crash-$i
  { echo "## run $i host $(date +%H:%M:%S) device $(adb -s $SER shell date +%H:%M:%S)"; adb -s $SER logcat -b crash -d -v time | grep -E "FATAL|LANDMARKS_CRASH" ; grep -E "Step [0-9]+ (failed|completed)|crashed=true" $E/A3-crash/crash-$i-maestro-runner.log | cut -c1-220; } >> $E/A3-crash/device-crash-times.txt 2>&1
done
for i in 1 2 3; do $F android .maestro/03-edit.yaml $E/A1-03edit run-$i; done
for i in 1 2 3; do $F android .maestro/10-seed-many.yaml $E/A-seed-many seed-$i --snapshot full; done
for i in 1 2 3 4 5 6 7 8 9 10; do $F android .maestro/02-favorite.yaml $E/A-K07-swipe fav-$i; done
for i in 1 2 3 4 5; do $F android .maestro/coverage/03-gesture-lab-taps.yaml $E/A-doubletap dt-$i; done
echo BATCH-DONE
