ps -p $(cat $S/ka.pid) -o pid=; $GRANTIVA runner stop; echo rc=$?; sleep 2; ps -p $(cat $S/ka.pid) -o pid= || echo keep-alive-gone; ls /tmp/grantiva-sessions/
