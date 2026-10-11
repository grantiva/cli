rm -rf out out.ready; $GRANTIVA run --report-dir out --ready-file out.ready; echo exit=$?; cat out.ready; echo; adb devices
