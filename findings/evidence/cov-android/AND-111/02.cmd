$GRANTIVA build build; echo rc=$?; sleep 5; adb devices; ps -axo command | grep -c "[q]emu-system"
