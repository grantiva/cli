$GRANTIVA record --duration 2 --json  --output $S/r139.mp4 > $S/r139-plain.json 2> $S/r139-plain.err; echo rc=$?; wc -l < $S/r139-plain.err; head -3 $S/r139-plain.err | cut -c1-160
