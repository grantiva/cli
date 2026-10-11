$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/cov-tmp/09-noheader.yaml --env LANDMARKS_SEED=empty 2>&1 | grep -E "PASS|FAIL|╰"; $S/tools/launchlog.sh
