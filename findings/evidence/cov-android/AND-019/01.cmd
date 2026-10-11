$GRANTIVA build build --verbose 2>&1 | grep -E "gradlew|assemble|exit [0-9]+:.*gradlew" | head -5; echo; $GRANTIVA build build; echo rc=$?
