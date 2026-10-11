adb forward --list; $GRANTIVA hierarchy --verbose 2>&1 >/dev/null | grep -E "forward" | cut -c1-200; adb forward --list
