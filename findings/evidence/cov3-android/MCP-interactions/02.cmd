/Users/kyle/.grantiva-qa/bin/grantiva runner stop --json; echo stop-exit=$?; test ! -e .grantiva/session.json; echo no-session-exit=$?; adb forward --list
