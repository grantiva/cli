$GRANTIVA record --emulator cov-android --duration 2 --json | grep -E "\"(emulator|serial|simulator|udid)\""; echo rc=$?
