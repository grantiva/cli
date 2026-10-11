$GRANTIVA run --device emulator-5554 --no-build --flow .maestro/coverage/16-setpermissions.yaml 2>&1 | grep -vE "^\s+[✓✗]|^─|^═|^$" | head -30; echo rc=${PIPESTATUS[0]}
