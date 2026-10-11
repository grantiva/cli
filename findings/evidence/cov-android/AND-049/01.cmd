rm -f $S/r049.ready; $GRANTIVA run --device emulator-5554 --no-build --flow .maestro/coverage/18-long-wait.yaml --timeout 30 --ready-file $S/r049.ready; echo rc=$?; cat $S/r049.ready
