rm -f $S/r040.ready; $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/01-browse.yaml --env LANDMARKS_CRASH_ON_LAUNCH=1 --ready-file $S/r040.ready; echo rc=$?; cat $S/r040.ready
