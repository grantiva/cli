$GRANTIVA emulator delete --name cov-android-3x; $GRANTIVA emulator sessions >/dev/null; cat ~/.grantiva/android/created-avds.json; avdmanager list avd | grep Name
