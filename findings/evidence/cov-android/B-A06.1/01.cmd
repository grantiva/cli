rm -f $S/x.ready; $GRANTIVA run --no-build --flow .maestro/05-category.yaml --device emulator-5554 --ready-file $S/x.ready >/dev/null 2>&1; echo rc=$?; cat $S/x.ready
