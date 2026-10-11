$GRANTIVA record --duration 2 --json --verbose --output $S/r139.mp4 > $S/r139-verbose.json 2> $S/r139-verbose.err; echo rc=$?; wc -l < $S/r139-verbose.err; head -3 $S/r139-verbose.err | cut -c1-160
