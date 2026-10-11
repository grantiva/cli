$GRANTIVA runner stop; echo rc=$?; adb forward --list | grep -c "emulator-5554 tcp:" || true
