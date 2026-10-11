rm -f /tmp/cov-ios-advertise.ready
$GRANTIVA run --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/cov-ios-advertise.ready > $S/ka130.out 2> $S/ka130.err &
G=$!
while [ ! -f /tmp/cov-ios-advertise.ready ]; do sleep 0.2; done
jq -r .status /tmp/cov-ios-advertise.ready   # passed | failed | interrupted
kill -INT $G; wait $G; echo "run exit=$?"; rm -f /tmp/cov-ios-advertise.ready
