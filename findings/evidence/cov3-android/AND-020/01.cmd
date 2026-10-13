$GRANTIVA build install; echo exit=$?; sleep 3; adb -s emulator-5554 shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity" | head -3
