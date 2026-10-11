grantiva() { $GRANTIVA "$@"; }
export GRANTIVA_SESSION_ID=cov-ios-tmp
grantiva simulator ensure --name "cov-ios-3 iPhone 17"
# build, install, and run as needed
grantiva simulator teardown --session-id cov-ios-tmp
echo "teardown exit=$?"
xcrun simctl list devices | grep -c "cov-ios-3" 
