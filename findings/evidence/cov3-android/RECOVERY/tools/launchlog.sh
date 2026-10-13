#!/bin/bash
# launchlog.sh [serial] [n]: last n "Landmarks: launch" logcat lines
s=${1:-emulator-5554}; adb -s $s logcat -d -s Landmarks:I | grep 'launch action' | tail -${2:-1}
