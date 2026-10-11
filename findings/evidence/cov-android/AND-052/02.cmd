$GRANTIVA emulator teardown --serial emulator-5556; sleep 3; $GRANTIVA emulator delete --name cov-android-2; adb devices; avdmanager list avd | grep Name
