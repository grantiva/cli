$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/02-favorite.yaml 2>&1 | grep -E 'Running|TOTAL|PASS|FAIL'
