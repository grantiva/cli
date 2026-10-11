grep -nE "Warning|Installing|Resolved|application|paid" $E/AND-026/01.err | head; jq -r .app.id $S/out-026/report.json; adb -s emulator-5554 shell pm list packages | grep landmarks
