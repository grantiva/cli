$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/09-seed-empty.yaml 2>&1 | grep -E "PASS|FAIL|╰"; $S/tools/launchlog.sh
