adb devices; cat ~/.grantiva/android/started.json; ps -p $(cat $S/hand-boot.pid) -o pid=,command= | cut -c1-120
