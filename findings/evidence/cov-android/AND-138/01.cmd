$GRANTIVA diff capture --device emulator-5554 --no-build --json  > $S/c138-plain.json 2> $S/c138-plain.err; echo rc=$?; wc -l < $S/c138-plain.err; grep -c '^\[debug\]' $S/c138-plain.err
