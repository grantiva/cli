#!/bin/bash
# ui.sh [serial]: print the non-empty text/content-desc values on screen now
s=${1:-emulator-5554}; adb -s $s shell uiautomator dump /sdcard/u.xml >/dev/null 2>&1; adb -s $s shell cat /sdcard/u.xml | grep -oE '(text|content-desc)="[^"]+"' | tr '\n' ' '; echo
