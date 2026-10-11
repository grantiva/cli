$GRANTIVA diff capture --no-build; echo exit=$?; kill -0 39267 && echo runner-still-alive; $GRANTIVA runner dump-hierarchy --format tree | head -3
