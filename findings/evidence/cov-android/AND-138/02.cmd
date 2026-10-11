$GRANTIVA diff capture --device emulator-5554 --no-build --json --quiet > $S/c138-quiet.json 2> $S/c138-quiet.err; echo rc=$?; wc -l < $S/c138-quiet.err; grep -c '^\[debug\]' $S/c138-quiet.err
