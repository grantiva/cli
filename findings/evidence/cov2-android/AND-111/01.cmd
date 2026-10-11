$GRANTIVA emulator teardown --serial emulator-5554 >/dev/null 2>&1; sleep 3; adb devices; $GRANTIVA build build; echo exit=$?; adb devices; ps -ax -o args= | grep -c '[q]emu-system.*cov2-android '
