$GRANTIVA runner start --detach --json --device emulator-5554 --headless; echo exit=$?; cat .grantiva/session.json; echo; $GRANTIVA runner stop --json; echo exit=$?
