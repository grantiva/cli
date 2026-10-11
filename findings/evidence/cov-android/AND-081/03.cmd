$GRANTIVA runner dump-hierarchy --format xml > $S/dh.xml; echo rc=$?; wc -c < $S/dh.xml; head -c 400 $S/dh.xml
