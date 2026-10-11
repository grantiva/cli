$GRANTIVA runner stop --json; echo exit=$?; ls /tmp/grantiva-sessions; ls .grantiva/session.json 2>&1; adb forward --list; $GRANTIVA runner stop --json; echo exit=$?
