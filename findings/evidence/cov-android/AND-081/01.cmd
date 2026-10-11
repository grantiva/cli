$GRANTIVA runner dump-hierarchy --format tree > $S/dh.tree; echo rc=$?; wc -c < $S/dh.tree; head -c 400 $S/dh.tree
