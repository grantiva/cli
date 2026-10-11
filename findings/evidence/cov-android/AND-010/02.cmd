$GRANTIVA build install --device emulator-5556 --no-build --app-file $P/app/build/outputs/apk/free/debug/app-free-debug.apk 2>&1 | tail -3; $GRANTIVA runner start --detach --device emulator-5556
