$S/tools/intrun.sh $E/B-A07.1/run 12 --no-build --flow .maestro/coverage/18-long-wait.yaml --device emulator-5554 --logs; sleep 5; ps -axo pid,ppid,command | grep "[a]db.*logcat" || echo no-logcat
