$GRANTIVA run --no-build --flow .maestro/08-caching.yaml --device emulator-5554 --logs --logs-level default --verbose 2>&1 | grep -E 'logcat' | grep -v 'exit ' | head -2 | cut -c1-260; $GRANTIVA run --no-build --flow .maestro/08-caching.yaml --device emulator-5554 --logs --logs-level default 2>&1 | grep '^\[log\]' | awk '{print substr($4,1,1)}' | sort | uniq -c | tr '
' ' '
