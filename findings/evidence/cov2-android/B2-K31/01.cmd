$GRANTIVA emulator ensure --name cov2-android-x --system-image "system-images;android-99;bogus;arm64-v8a" --no-boot; echo exit=$?; avdmanager list avd -c; cat ~/.grantiva/android/created-avds.json
