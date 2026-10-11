$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/cov-tmp/09-noheader.yaml 2>&1 | grep -E "PASS|FAIL|╰" | head -3
