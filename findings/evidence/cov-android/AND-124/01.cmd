$GRANTIVA record --duration 4 >/dev/null; echo rc=$?; ffprobe -v error -show_entries format=duration -of csv=p=0 .grantiva/recordings/recording.mp4
