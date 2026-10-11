grep -E "hw.device.name|image.sysdir|abi.type|tag.id" ~/.android/avd/cov-android.avd/config.ini; adb devices; adb -s emulator-5554 emu avd name
