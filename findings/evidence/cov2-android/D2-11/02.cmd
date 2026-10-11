( sleep 4.5; adb -s emulator-5554 shell input tap 540 1300 ) & /Users/kyle/.grantiva-qa/bin/grantiva record --device emulator-5554 --duration 4 --json --verbose; echo exit=$?; wait
