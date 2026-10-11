adb devices; $GRANTIVA run --no-build --flow .maestro/01-browse.yaml 2>&1 | grep -E "Resolved|No emulator|Emulator booted|PASS|FAIL"
