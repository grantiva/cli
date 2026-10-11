$GRANTIVA runner dump-hierarchy --format json > $S/dh.json; echo rc=$?; wc -c < $S/dh.json; head -c 400 $S/dh.json
