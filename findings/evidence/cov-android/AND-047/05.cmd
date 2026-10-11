for m in failure trailing full ok; do echo "== $m"; find $S/out-snap-$m/assets $S/out-snap-$m/captures -type f 2>/dev/null | sed "s|$S/out-snap-$m/||" | sort; done
