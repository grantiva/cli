$GRANTIVA emulator teardown --serial emulator-5556; sleep 3; adb devices; $GRANTIVA emulator delete --name cov-android-2; avdmanager list avd | grep Name
