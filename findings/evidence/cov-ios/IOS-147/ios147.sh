grantiva() { $GRANTIVA "$@"; }
udid=$(grantiva simulator ensure --name "cov-ios-3 iPhone 17")
echo "udid=$udid"
grantiva run --simulator "$udid" --flow .maestro/01-browse.yaml
echo "run exit=$?"
