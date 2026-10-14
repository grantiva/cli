# Candidate5 Android window return review

APPROVED. Root inspected FINAL-STATE raw commands and outputs in commits 7cc03cdfe, 610eecd52 and fea4d86bf. All relevant commands have expected exit, current identity and no collector cleanup failure. Primary generation4 is emulator-5554/PID91961 with retained start time and exact headless argv; frozen APK hash5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a was restored successfully. Extra AVD deleted, adb inventory only primary, global forwards empty, sessions only primary. Protected Pixel config hash remains3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27.

First runner-absence capture used an incorrectly escaped ERE and is excluded. Adjacent corrected ERE uses [.] and [+], matches a positive sample with grep -E, and the identical expression returns pgrep exit1/empty stdout. Both campaign session files are absent. No broad process capture is needed. iOS owns the live window; Android held.
