script -q /dev/null $GRANTIVA emulator ensure --name cov-android-2 --headless </dev/null; ps -axo pid,command | grep "[q]emu.*cov-android-2" | cut -c1-220
