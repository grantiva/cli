$GRANTIVA runner start --detach --application-id x.y --emulator cov2-android; echo exit=$?; cat .grantiva/session.json; echo; $GRANTIVA runner stop; echo exit=$?
