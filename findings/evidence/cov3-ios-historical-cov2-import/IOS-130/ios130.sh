rm -f /tmp/cov2-ios-advertise.ready
$GRANTIVA run --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/cov2-ios-advertise.ready > $E/IOS-130/ka130.out 2> $E/IOS-130/ka130.err &
G=$!
while [ ! -f /tmp/cov2-ios-advertise.ready ]; do sleep 0.2; done
jq -r .status /tmp/cov2-ios-advertise.ready   # passed | failed | interrupted
kill -INT $G; wait $G; echo "run exit=$?"; rm -f /tmp/cov2-ios-advertise.ready
