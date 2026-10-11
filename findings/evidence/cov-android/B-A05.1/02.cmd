ffprobe -v error -select_streams v:0 -show_entries frame=pts_time,duration_time -of csv=p=0 $S/a05.mp4
