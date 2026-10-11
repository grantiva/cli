adb devices; ps -p $(cat $S/hand-boot.pid) -o pid= || echo "hand-boot pid gone"
