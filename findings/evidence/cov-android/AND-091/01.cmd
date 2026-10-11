env -u ANDROID_HOME -u ANDROID_SDK_ROOT $GRANTIVA doctor --platform android | grep -E "SDK|adb|Emulator|passed"; echo rc=${PIPESTATUS[0]}
