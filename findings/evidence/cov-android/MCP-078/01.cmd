adb -s emulator-5554 shell am force-stop com.kylebrowning.landmarks; adb -s emulator-5554 shell pidof com.kylebrowning.landmarks || echo app-stopped
