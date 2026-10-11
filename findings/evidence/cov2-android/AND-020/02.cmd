adb -s emulator-5554 shell pidof com.kylebrowning.landmarks; adb -s emulator-5554 shell dumpsys activity activities | grep -m1 topResumedActivity
