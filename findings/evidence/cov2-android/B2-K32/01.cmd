adb -s emulator-5554 uninstall com.kylebrowning.landmarks; adb -s emulator-5554 uninstall com.kylebrowning.landmarks.paid; $GRANTIVA build install --no-build --device emulator-5554; echo exit=$?
