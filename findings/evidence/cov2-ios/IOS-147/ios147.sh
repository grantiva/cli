grantiva() { $GRANTIVA "$@"; }
udid=$(grantiva simulator ensure --name "cov2-ios-3 iPhone 17")
echo "captured udid=[$udid]"
grantiva run --simulator "$udid" --flow .maestro/01-browse.yaml
echo "run exit=$?"
