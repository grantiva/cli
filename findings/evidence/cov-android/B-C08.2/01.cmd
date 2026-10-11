$GRANTIVA diff capture --device emulator-5554 --no-build 2>&1 | grep -E "id=|✓|✗|Captured|Error"; echo rc=${PIPESTATUS[0]}
