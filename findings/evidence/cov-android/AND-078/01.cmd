$GRANTIVA record --device emulator-5554 --duration 2 --json | grep -E "\"(emulator|serial|simulator|udid)\""; echo rc=$?
