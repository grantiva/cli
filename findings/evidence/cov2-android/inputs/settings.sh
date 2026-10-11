#!/bin/bash
# settings.sh [serial]: the settings grantiva changes, plus forwards and uia2 processes
s=${1:-emulator-5554}
for k in global:sysui_demo_allowed global:window_animation_scale global:transition_animation_scale global:animator_duration_scale system:accelerometer_rotation system:user_rotation; do echo "$k=$(adb -s $s shell settings get ${k%%:*} ${k#*:} | tr -d '\r')"; done
echo "forwards: $(adb forward --list | grep $s | tr '\n' ';')"
echo "uia2: $(adb -s $s shell ps -A | grep -c uiautomator)"
echo "demo-clock: $(adb -s $s shell dumpsys window | grep -c 'DemoMode' )"
