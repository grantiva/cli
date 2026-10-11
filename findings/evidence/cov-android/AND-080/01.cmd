$GRANTIVA runner start --detach; echo rc=$?; cat .grantiva/session.json; echo; adb forward --list
