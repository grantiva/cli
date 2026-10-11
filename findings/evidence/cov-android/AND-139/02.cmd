$GRANTIVA record --duration 2 --json --quiet --output $S/r139.mp4 > $S/r139-quiet.json 2> $S/r139-quiet.err; echo rc=$?; wc -l < $S/r139-quiet.err; head -3 $S/r139-quiet.err | cut -c1-160
