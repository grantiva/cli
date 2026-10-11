adb devices; ps -axo pid,command | grep "[q]emu.*cov-android-2" | cut -c1-150; cat ~/.grantiva/android/started.json
