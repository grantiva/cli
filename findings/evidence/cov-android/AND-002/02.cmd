$GRANTIVA emulator ensure --name cov-android-2 --system-image "system-images;android-99;bogus;arm64-v8a" --no-boot; avdmanager list avd | grep -c cov-android-2
