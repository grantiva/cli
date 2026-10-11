($GRANTIVA run --no-build --flow .maestro/11-slow.yaml --device emulator-5554 --logs  >/dev/null 2>&1 &) ; sleep 5; ps -axo command | grep '[a]db.*logcat' | cut -c1-200; sleep 6
