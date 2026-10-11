$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/04-discard.yaml 2>&1 | grep -E 'Running|TOTAL|PASS|FAIL'
