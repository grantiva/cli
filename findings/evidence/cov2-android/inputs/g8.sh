#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/env.sh
cd $P; R="$GRANTIVA record --device emulator-5554"; FP="ffprobe -v error -show_entries format=duration:stream=nb_frames,duration -of compact"
adb -s emulator-5554 shell am start -n com.kylebrowning.landmarks/.MainActivity >/dev/null 2>&1; sleep 8
rec AND-076 "rm -rf .grantiva/recordings; $GRANTIVA record --duration 5 --frames-at 0,1000,3000; echo exit=\$?; ls -la .grantiva/recordings; $FP .grantiva/recordings/recording.mp4; cat .grantiva/recordings/recording.json 2>/dev/null"
rec AND-077 "$GRANTIVA record --duration 181; echo exit=\$?"
rec AND-078 "$R --duration 2; echo exit=\$?; $GRANTIVA record --emulator cov2-android --duration 2; echo exit=\$?; $GRANTIVA record --duration 2 --verbose 2>&1 | grep -m3 'emulator-5554\|screenrecord'"
rec AND-079 "mkdir -p '$S/cov rec'; $R --duration 3 --frames-at 0,1000 --json --output '$S/cov rec/a.mp4'; echo exit=\$?; ls '$S/cov rec'"
rec AND-124 "$R --duration 4; echo exit=\$?"
rec AND-139 "$R --duration 2 --json > $E/AND-139/plain.json 2> $E/AND-139/plain.err; $R --duration 2 --json --quiet > $E/AND-139/quiet.json 2> $E/AND-139/quiet.err; $R --duration 2 --json --verbose > $E/AND-139/verbose.json 2> $E/AND-139/verbose.err; wc -l $E/AND-139/*.err; md5 -q $E/AND-139/*.json; head -40 $E/AND-139/verbose.err"
rec X-010 "$R --duration 3 --frames-at 0,1000 --json; echo exit=\$?"
rec B-A05.1 "rm -rf .grantiva/recordings; $R --duration 2 --frames-at 1000 --json; echo exit=\$?; ls .grantiva/recordings; $FP .grantiva/recordings/recording.mp4"
rec B2-K34-a "$R --duration 2 --frames-at 1000 --json --verbose; echo exit=\$?"
for i in 1 2 3 4 5 6 7 8 9 10; do rec B2-K34-b "$R --duration 4 --verbose --json --output $S/k34b-\$((RANDOM)).mp4 2>&1 | grep -E 'note|Note|Held frame|appears|held|recordedMilliseconds|lastFrame'; echo exit=\${PIPESTATUS[0]}"; done
rec B2-K84 "rm -rf .grantiva/recordings; $R --duration 3 --frames-at 0; echo exit=\$?; md5 -q .grantiva/recordings/recording.mp4; t0=\$(python3 -I -c 'import time;print(time.time())'); $R --duration 2 --frames-at 5000; echo exit=\$?; python3 -I -c \"import time;print('secs',round(time.time()-\$t0,2))\"; md5 -q .grantiva/recordings/recording.mp4; $R --duration 2 --frames-at 2000; echo exit-at-2000=\$?"
rec B2-K85 "mkdir -p rel; $R --duration 3 --frames-at 0,1000 --output rel/r.mp4; echo exit=\$?; $R --duration 3 --frames-at 0,1000 --output rel/r.mp4 --json; echo exit=\$?; $R --duration 3 --frames-at 0,1000 --output $S/abs/r.mp4; echo exit=\$?; $R --duration 3 --frames-at 0,1000 --output $S/abs/r.mp4 --json; echo exit=\$?"
for i in 1 2 3 4 5; do rec B2-K111 "$R --duration 4 --output $S/k111-r$i.mp4 --verbose --json > $E/B2-K111/r$i.json; echo exit=\$?; $FP $S/k111-r$i.mp4; python3 -I -c \"import json;d=json.load(open('$E/B2-K111/r$i.json'));print({k:v for k,v in d.items() if 'illi' in k or k in ('video','duration')})\""; done
rec B2-K111 "$R --duration 4 --frames-at 4000 --output $S/k111-f.mp4 --json; echo exit=\$?"
rec D2-11 "$R --duration 4 --json --verbose; echo exit=\$?"
rec D2-11 "( sleep 4.5; adb -s emulator-5554 shell input tap 540 1300 ) & $R --duration 4 --json --verbose; echo exit=\$?; wait"
rec D2-12 "$R --duration 2 --frames-at 5000; echo exit=\$?; $R --duration 2 --frames-at 0,1000 --output rel/r2.mp4; $R --duration 2 --frames-at 0,1000 --output rel/r2.mp4 --json; $R --duration 2 --frames-at 0,1000 --output $S/abs/r2.mp4; $R --duration 2 --frames-at 0,1000 --output $S/abs/r2.mp4 --json"
rec B2-K33 "$R --duration 2 --json --verbose 2>&1 >/dev/null | grep -E '\\\$ |exit [0-9]|stopped by'; $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/08-caching.yaml --logs --verbose 2>&1 | grep -E '\\\$ |exit [0-9]+:|stopped by' | cut -c1-200; $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/08-caching.yaml --logs 2>&1 | grep -c '\\\$ '"
echo G8-DONE
