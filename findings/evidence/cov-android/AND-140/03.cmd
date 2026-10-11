$GRANTIVA diff capture --emulator cov-android --module app --variant freeDebug --headless --verbose 2>&1 | grep -E "gradlew|adb.* install|Captured|Emulator:" | cut -c1-250
