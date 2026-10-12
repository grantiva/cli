grantiva() { $GRANTIVA "$@"; }
export GRANTIVA_SESSION_ID=cov2-ios-tmp
grantiva simulator ensure --name "cov2-ios-3 iPhone 17"
# build, install, and run as needed
grantiva simulator teardown --session-id cov2-ios-tmp
echo "teardown exit=$?"
xcrun simctl list devices | grep -c "cov2-ios-3"
