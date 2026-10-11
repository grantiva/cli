#!/bin/bash
# sync, then tear down cov-android (emulator-5554) via grantiva
adb -s emulator-5554 shell sync >/dev/null 2>&1; sleep 2; $GRANTIVA emulator teardown --serial emulator-5554; sleep 3; adb devices
