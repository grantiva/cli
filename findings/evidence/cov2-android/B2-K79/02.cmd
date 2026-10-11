kill -0 37639 2>/dev/null && echo runner-alive || echo runner-gone; ls /tmp/grantiva-sessions | wc -l; adb forward --list; adb -s emulator-5554 shell ps -A | grep -c uiautomator
