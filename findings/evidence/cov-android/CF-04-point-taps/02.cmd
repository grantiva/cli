$S/tools/tools 2>/dev/null; $S/tools/cflow.sh 04-point-taps >/dev/null; $S/tools/ui.sh | grep -oE "(Taps|Last tap|Last swipe|Double taps|Long presses): [a-z0-9]+" | tr "
" " "; adb -s emulator-5554 shell wm size
