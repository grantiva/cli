$GRANTIVA runner start --detach --device emulator-5554 >/dev/null; adb -s emulator-5554 shell uiautomator dump /sdcard/u.xml >/dev/null; echo started
