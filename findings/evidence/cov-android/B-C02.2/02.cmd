$GRANTIVA emulator teardown --serial emulator-5558; sleep 3; $GRANTIVA emulator delete --name cov-android-2; kill 63449 2>/dev/null; adb devices; avdmanager list avd | grep Name
