adb -s emulator-5554 shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS; sleep 60; uptime; adb -s emulator-5554 shell uiautomator dump /sdcard/u.xml >/dev/null; adb -s emulator-5554 shell cat /sdcard/u.xml | grep -oE "(text|content-desc)=\"[^\"]+\"" | tr "
" " "
