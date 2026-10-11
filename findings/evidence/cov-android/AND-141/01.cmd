$GRANTIVA diff capture --device emulator-5554 --app-file app/build/outputs/apk/free/debug/app-free-debug.apk --verbose 2>&1 | grep -E "gradlew|apkanalyzer|install -r|Captured|•" | cut -c1-200
